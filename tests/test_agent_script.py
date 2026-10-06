"""Offline checks for the PDF crate's file-reference contract and runtime."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
CRATE = ROOT / "crates/pdf-summarizer"


class PDFScriptTests(unittest.TestCase):
    def test_fdl_placeholders_and_metadata_guidance(self):
        fdl_text = (CRATE / "fdl.yml").read_text()
        fdl = yaml.safe_load(fdl_text)
        service = fdl["functions"]["oscar"][0]["oscar-cluster"]
        variables = service["environment"]["variables"]
        self.assertEqual(service["script"], "script.sh")
        self.assertEqual(variables["AGENT_SOUL"], "YOUR_AGENT_SOUL")
        self.assertEqual(variables["AGENT_SKILLS"], "YOUR_AGENT_SKILLS")
        self.assertNotIn("# PDF Summarizer Soul", fdl_text)
        self.assertNotIn("# PDF Extract Skill", fdl_text)
        self.assertFalse((CRATE / ".env.example").exists())
        self.assertFalse((ROOT / "skills").exists())
        self.assertFalse((ROOT / "scripts").exists())
        self.assertNotIn("__OSCAR_AGENT_", fdl_text)
        self.assertNotIn("# PDF Summarizer Soul", (CRATE / "script.sh").read_text())
        self.assertNotIn("# PDF Extract Skill", (CRATE / "script.sh").read_text())

    def test_profile_and_local_rocrate_references(self):
        self.assertEqual({path.name for path in (ROOT / "profiles").iterdir() if path.is_dir()},
                         {"oscar-agent-1.1"})
        profile = json.loads((ROOT / "profiles/oscar-agent-1.1/ro-crate-metadata.json").read_text())
        profile_graph = {entity["@id"]: entity for entity in profile["@graph"]}
        profile_root = profile_graph["./"]
        self.assertEqual(profile_root["version"], "1.1")
        self.assertIn("Profile", profile_root["@type"])
        self.assertEqual(profile_root["isProfileOf"], {"@id": "https://w3id.org/ro/crate/1.2"})
        self.assertEqual(profile_graph["ro-crate-metadata.json"]["about"], {"@id": "./"})
        self.assertIn({"@id": "README.md"}, profile_root["hasPart"])
        profile_id = profile_root["identifier"]
        terms = {entity["name"] for entity in profile["@graph"]
                 if entity.get("@type") == "DefinedTerm"}
        self.assertEqual(terms, {"Agent", "AgentSoul", "AgentSkill",
                                 "agentSoul", "agentMode", "agentSkills"})
        for term in terms:
            self.assertIn(f"{profile_id}#{term}", profile_graph)
        self.assertFalse((ROOT / "profiles/oscar-agent-1.1/ro-crate-profile.json").exists())
        for slug, mode in (("pdf-summarizer", "asynchronous"),
                           ("hermes-dashboard", "exposed")):
            crate = ROOT / "crates" / slug
            metadata = json.loads((crate / "ro-crate-metadata.json").read_text())
            graph = {entity["@id"]: entity for entity in metadata["@graph"]}
            root = graph["./"]
            self.assertEqual(root["conformsTo"]["@id"], profile_id)
            self.assertIn(profile_id, graph)
            self.assertEqual(root["agentMode"], "on-demand" if slug == "pdf-summarizer" else "exposed")
            soul_text = (crate / "SOUL.md").read_text(encoding="utf-8")
            if soul_text.startswith("---\n"):
                frontmatter = yaml.safe_load(soul_text.split("---\n", 2)[1])
                self.assertNotIn("agentMode", frontmatter)
            self.assertEqual(root["url"],
                             f"https://github.com/grycap/oscar-agents/tree/devel/crates/{slug}")
            self.assertEqual(root["serviceType"], mode)
            self.assertNotIn("suggestedSkills", root)
            self.assertNotIn("suggestedSkills", metadata["@context"][1])
            self.assertEqual(metadata["@context"][1]["agentSoul"]["@type"], "@id")
            soul_id = root["agentSoul"]["@id"]
            self.assertEqual(soul_id, "SOUL.md")
            self.assertIn("AgentSoul", graph[soul_id]["@type"])
            self.assertIn({"@id": soul_id}, root["hasPart"])
            if slug == "pdf-summarizer":
                self.assertEqual(metadata["@context"][1]["agentSkills"]["@type"], "@id")
                self.assertEqual([item["@id"] for item in root["agentSkills"]],
                                 ["skills/pdf-extract/SKILL.md"])
                for item in root["agentSkills"]:
                    identifier = item["@id"]
                    self.assertIn(item, root["hasPart"])
                    self.assertIn("AgentSkill", graph[identifier]["@type"])
                    self.assertEqual(graph[identifier]["encodingFormat"], "text/markdown")
                    self.assertNotIn("skillSource", graph[identifier])
                self.assertFalse(any(identifier.startswith("https://") and
                                     "AgentSkill" in entity.get("@type", [])
                                     for identifier, entity in graph.items()))
            else:
                self.assertNotIn("agentSkills", root)
            for item in root["hasPart"]:
                identifier = item["@id"]
                self.assertEqual(identifier, str(Path(identifier)))
                self.assertFalse(Path(identifier).is_absolute())
                self.assertNotIn("..", Path(identifier).parts)
                self.assertIn(identifier, graph)
                self.assertTrue((crate / identifier).is_file(), identifier)
            for identifier in [soul_id] + [item["@id"] for item in root.get("agentSkills", [])]:
                path = (crate / identifier).resolve()
                self.assertTrue(path.is_relative_to(crate.resolve()))
                self.assertTrue(path.read_text(encoding="utf-8"))

    def test_crate_script_passes_soul_and_skill_to_hermes(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("HERMES_SCRATCH_DIR")) as directory:
            work = Path(directory)
            fake_hermes = work / "hermes"
            fake_hermes.write_text(
                '#!/bin/sh\n'
                'while [ "$#" -gt 0 ]; do\n'
                '  if [ "$1" = "-q" ]; then shift; printf "%s" "$1"; exit 0; fi\n'
                '  shift\n'
                'done\nexit 1\n'
            )
            fake_hermes.chmod(0o755)
            sample = work / "sample.pdf"
            sample.write_bytes(b"%PDF-1.4\n")
            output = work / "output"
            home = work / "hermes-home"
            env = {**os.environ,
                   "HERMES_BIN": str(fake_hermes),
                   "INPUT_FILE_PATH": str(sample),
                   "TMP_OUTPUT_DIR": str(output),
                   "HERMES_HOME": str(home),
                   "TMPDIR": str(work),
                   "OPENAI_API_KEY": "offline-test-only",
                   "OPENAI_BASE_URL": "https://example.invalid/v1",
                   "OPENAI_MODEL": "offline-test-model",
                   "LLM_PROVIDER_NAME": "offline-test-provider"}
            variables = yaml.safe_load((CRATE / "fdl.yml").read_text())[
                "functions"]["oscar"][0]["oscar-cluster"]["environment"]["variables"]
            # Simulate future RO-Crate guidance materialization, not current oscar-cli behavior.
            self.assertEqual(variables["AGENT_SOUL"], "YOUR_AGENT_SOUL")
            self.assertEqual(variables["AGENT_SKILLS"], "YOUR_AGENT_SKILLS")
            metadata = json.loads((CRATE / "ro-crate-metadata.json").read_text())
            root = next(entity for entity in metadata["@graph"] if entity["@id"] == "./")
            env["AGENT_SOUL"] = (CRATE / root["agentSoul"]["@id"]).read_text()
            env["AGENT_SKILLS"] = "\n\n".join(
                (CRATE / item["@id"]).read_text()
                for item in sorted(root["agentSkills"], key=lambda item: item["@id"]))
            result = subprocess.run(["sh", str(CRATE / "script.sh")], env=env,
                                    capture_output=True, text=True, check=True)
            self.assertIn("Result written", result.stdout)
            prompt = (output / "sample-result.txt").read_text()
            self.assertIn("# PDF Summarizer Soul", prompt)
            self.assertIn("# PDF Extract Skill", prompt)
            self.assertIn("Agent skill guidance:", prompt)
            self.assertNotIn("{{ agentSkills }}", prompt)
            self.assertNotIn('{{ file "SOUL.md" }}', prompt)
            self.assertIn("/sample.pdf", prompt)

            env["AGENT_SOUL"] = "A customized soul"
            env["AGENT_SKILLS"] = "A customized skill"
            subprocess.run(["sh", str(CRATE / "script.sh")], env=env,
                           capture_output=True, text=True, check=True)
            edited_prompt = (output / "sample-result.txt").read_text()
            self.assertIn("A customized soul", edited_prompt)
            self.assertIn("A customized skill", edited_prompt)
            self.assertNotIn("# PDF Summarizer Soul", edited_prompt)

            for key, unresolved in (("AGENT_SOUL", "YOUR_AGENT_SOUL"),
                                    ("AGENT_SKILLS", "YOUR_AGENT_SKILLS")):
                bad_env = {**env, key: unresolved}
                invalid = subprocess.run(["sh", str(CRATE / "script.sh")], env=bad_env,
                                         capture_output=True, text=True)
                self.assertNotEqual(invalid.returncode, 0)
                self.assertIn(f"{key} must contain resolved guidance", invalid.stderr)

            env.pop("AGENT_SOUL")
            missing = subprocess.run(["sh", str(CRATE / "script.sh")], env=env,
                                     capture_output=True, text=True)
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn("AGENT_SOUL is not set", missing.stderr)


if __name__ == "__main__":
    unittest.main()
