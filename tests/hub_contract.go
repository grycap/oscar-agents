// Run from the oscar-cli module: go run ../oscar-agents/tests/hub_contract.go ../oscar-agents/crates
// Exercises the real local and remote Hub FDL loaders without a cluster or GitHub traffic.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"

	"github.com/grycap/oscar-cli/v2/pkg/hub"
	"github.com/grycap/oscar-cli/v2/pkg/service"
)

func singleService(fdl *service.FDL) (string, string, map[string]string, error) {
	for _, entry := range fdl.Functions.Oscar {
		for _, svc := range entry {
			if svc != nil {
				return svc.Name, svc.Script, svc.Environment.Vars, nil
			}
		}
	}
	return "", "", nil, fmt.Errorf("no OSCAR service in FDL")
}

func check(root, slug string) error {
	crate := filepath.Join(root, slug)
	fdlData, err := os.ReadFile(filepath.Join(crate, "fdl.yml"))
	if err != nil {
		return err
	}
	scriptData, err := os.ReadFile(filepath.Join(crate, "script.sh"))
	if err != nil {
		return err
	}
	if slug == "pdf-summarizer" {
		for _, relative := range []string{"SOUL.md", "skills/pdf-extract/SKILL.md"} {
			if _, err := os.ReadFile(filepath.Join(crate, relative)); err != nil {
				return err
			}
		}
	}
	local, err := hub.LoadLocalFDL(root, slug)
	if err != nil {
		return fmt.Errorf("local load: %w", err)
	}

	apiPrefix := "/repos/grycap/oscar-agents/contents/crates/" + slug
	requests := map[string]bool{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests[r.URL.Path] = true
		switch r.URL.Path {
		case apiPrefix:
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode([]map[string]string{
				{"name": "fdl.yml", "path": "crates/" + slug + "/fdl.yml", "type": "file"},
				{"name": "script.sh", "path": "crates/" + slug + "/script.sh", "type": "file"},
			})
		case apiPrefix + "/fdl.yml":
			_, _ = w.Write(fdlData)
		case apiPrefix + "/script.sh":
			_, _ = w.Write(scriptData)
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()
	client := hub.NewClient(hub.WithOwner("grycap"), hub.WithRepo("oscar-agents"),
		hub.WithRootPath("crates"), hub.WithBaseAPI(server.URL), hub.WithHTTPClient(server.Client()))
	remote, err := client.FetchFDL(context.Background(), slug)
	if err != nil {
		return fmt.Errorf("remote artifact load: %w", err)
	}
	if !requests[apiPrefix+"/fdl.yml"] || !requests[apiPrefix+"/script.sh"] {
		return fmt.Errorf("remote loader did not request both FDL and script")
	}
	for label, fdl := range map[string]*service.FDL{"local": local, "remote": remote} {
		name, script, vars, err := singleService(fdl)
		if err != nil {
			return err
		}
		if name != slug || script != string(scriptData) {
			return fmt.Errorf("%s load did not embed the expected %s script", label, slug)
		}
		for _, field := range []string{"AGENT_SOUL", "AGENT_SKILLS"} {
			if strings.Contains(vars[field], "{{") {
				return fmt.Errorf("%s load contains unexpanded %s template", label, field)
			}
		}
		if slug == "pdf-summarizer" {
			if strings.Contains(script, "# PDF Summarizer Soul") || strings.Contains(script, "# PDF Extract Skill") {
				return fmt.Errorf("%s script contains duplicated agent guidance", label)
			}
			if vars["AGENT_SOUL"] != "YOUR_AGENT_SOUL" {
				return fmt.Errorf("%s loader unexpectedly resolved soul placeholder", label)
			}
			if vars["AGENT_SKILLS"] != "YOUR_AGENT_SKILLS" {
				return fmt.Errorf("%s loader unexpectedly resolved skills placeholder", label)
			}
		}
	}
	fmt.Printf("PASS %s: local and mocked-remote FDL loads preserve script and current literal variables\n", slug)
	return nil
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: hub_contract CRATES_DIR")
		os.Exit(2)
	}
	for _, slug := range []string{"pdf-summarizer", "hermes-dashboard"} {
		if err := check(os.Args[1], slug); err != nil {
			fmt.Fprintf(os.Stderr, "FAIL %s: %v\n", slug, err)
			os.Exit(1)
		}
	}
}
