#!/usr/bin/env python3
"""Copy/download the project's "main" figures listed in results.yaml.

Behavior:
  * Reads results.yaml (in the current directory by default).
  * Determines whether the source files are LOCAL (we're on the cluster
    or have a clone of the project) or REMOTE (need to fetch from rhino).
  * Detection: if `<project_root>/results.yaml` exists at its absolute
    path, we're local — use cp. Otherwise we're remote — stream the files
    over a SINGLE ssh connection via `tar | ssh | tar` (one handshake
    instead of one per file).
  * Output directory:
      - If a positional CLI arg is given, use that.
      - Otherwise default to `<project_root>/results/figures/main/` if
        we're local, or `./` if we're remote.
  * Each section in results.yaml becomes a subdirectory of the output
    dir (e.g. `main/serialpos_x_recall_FR1_pooled/...`).

Usage:
  # On rhino (or any machine with the project cloned locally):
  python download_main_figures.py                # -> results/figures/main/
  python download_main_figures.py /tmp/myout     # -> /tmp/myout/

  # From a remote machine (uses the hard-coded SSH_TARGET below):
  python download_main_figures.py                # -> ./
  python download_main_figures.py ~/figures      # -> ~/figures/
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("error: PyYAML is required. Install with: pip install pyyaml")


# SSH target for remote-mode runs. Edit this if your rhino login changes.
SSH_TARGET = "rdehaan@rhino2.psych.upenn.edu"


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("output_dir", nargs="?", default=None,
                   help="Where to copy the figures. Defaults to "
                        "<project>/results/figures/main/ if local, else ./")
    p.add_argument("--manifest", default="results.yaml",
                   help="Path to the YAML manifest (default: results.yaml)")
    p.add_argument("--dry-run", action="store_true",
                   help="Print what would be copied without copying")
    p.add_argument("--ssh-target", default=SSH_TARGET,
                   help=f"SSH target for remote mode (default: {SSH_TARGET})")
    return p.parse_args()


def fetch_remote_via_tar(ssh_target, project_root, file_specs, out_dir, dry_run):
    """Stream remote files in a single ssh connection using tar.

    file_specs: list of (rel_path_str, dest_path) tuples.
    The remote command tars all rel_paths from project_root to stdout;
    locally we untar to a temp dir and then move each file to its dest.

    Returns (n_ok, n_missing).
    """
    import tempfile

    rel_paths = [str(p) for p, _ in file_specs]

    # Build the remote tar command. We `cd` into project_root and tar the
    # listed paths to stdout. Use --ignore-failed-read so missing files
    # don't abort the whole stream; we'll detect missing files locally.
    remote_cmd = (
        f"cd {project_root.as_posix()} && "
        f"tar -cf - --ignore-failed-read " +
        " ".join(f"'{rp}'" for rp in rel_paths)
    )

    if dry_run:
        print(f"  [dry-run] would run: ssh {ssh_target} \"{remote_cmd}\"")
        for rel, dest in file_specs:
            print(f"  [dry-run] -> {dest}")
        return len(file_specs), 0

    print(f"  streaming {len(file_specs)} files via single ssh connection...")

    with tempfile.TemporaryDirectory() as tmpdir:
        # Pipe: ssh user@host "tar -cf - <files>" | tar -xf - -C tmpdir
        ssh_proc = subprocess.Popen(
            ["ssh", ssh_target, remote_cmd],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        tar_proc = subprocess.Popen(
            ["tar", "-xf", "-", "-C", tmpdir],
            stdin=ssh_proc.stdout,
            stderr=subprocess.PIPE,
        )
        ssh_proc.stdout.close()  # let ssh receive SIGPIPE if tar exits
        tar_stderr = tar_proc.communicate()[1]
        ssh_stderr = ssh_proc.communicate()[1]

        if ssh_proc.returncode != 0 and not Path(tmpdir).iterdir():
            print(f"  ERROR ssh returned {ssh_proc.returncode}: "
                  f"{ssh_stderr.decode(errors='replace').strip()}")
            return 0, len(file_specs)

        # Move each fetched file from the temp dir to its dest. Files
        # missing from the temp dir indicate missing-on-remote.
        n_ok = 0
        n_missing = 0
        tmp_root = Path(tmpdir)
        for rel, dest in file_specs:
            src_in_tmp = tmp_root / rel
            if src_in_tmp.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(src_in_tmp), str(dest))
                print(f"  ok       {Path(rel).name}")
                n_ok += 1
            else:
                print(f"  MISSING  {rel}")
                n_missing += 1

        return n_ok, n_missing


def main():
    args = parse_args()

    manifest_path = Path(args.manifest).resolve()
    if not manifest_path.exists():
        sys.exit(f"error: manifest not found: {manifest_path}")

    with manifest_path.open() as f:
        manifest = yaml.safe_load(f)

    project_root = Path(manifest["project_root"])
    sections = manifest.get("sections", {})
    if not sections:
        sys.exit("error: manifest has no `sections:`")

    # ---- Local vs remote detection ----
    local_mode = project_root.exists() and (project_root / "results.yaml").exists()

    if local_mode:
        print(f"[local] project root: {project_root}")
    else:
        print(f"[remote] ssh target:        {args.ssh_target}")
        print(f"         remote project:    {project_root}")

    # ---- Resolve output directory ----
    if args.output_dir is not None:
        out_dir = Path(args.output_dir).expanduser().resolve()
    elif local_mode:
        out_dir = (project_root / "results" / "figures" / "main").resolve()
    else:
        out_dir = Path.cwd().resolve()

    print(f"[output] {out_dir}")
    print()

    # ---- Local mode: cp file by file ----
    if local_mode:
        n_total = n_ok = n_missing = 0
        for section_name, file_list in sections.items():
            if not file_list:
                continue
            section_out = out_dir / section_name
            if not args.dry_run:
                section_out.mkdir(parents=True, exist_ok=True)
            print(f"=== {section_name} -> {section_out} ===")

            for rel_path in file_list:
                n_total += 1
                src_rel = Path(rel_path)
                dest    = section_out / src_rel.name
                src     = project_root / src_rel
                if not src.exists():
                    print(f"  MISSING  {src}")
                    n_missing += 1
                    continue
                if args.dry_run:
                    print(f"  cp       {src} -> {dest}")
                else:
                    shutil.copy2(src, dest)
                    print(f"  ok       {src_rel.name}")
                n_ok += 1
            print()

    # ---- Remote mode: ONE ssh connection, tar-stream everything ----
    else:
        # Build a flat list of (rel_path, dest_path) tuples across all sections,
        # creating section subdirs up front so the temp-dir move step lands
        # files in the right place.
        file_specs = []
        for section_name, file_list in sections.items():
            if not file_list:
                continue
            section_out = out_dir / section_name
            if not args.dry_run:
                section_out.mkdir(parents=True, exist_ok=True)
            print(f"=== {section_name} -> {section_out} ===")
            for rel_path in file_list:
                src_rel = Path(rel_path)
                dest    = section_out / src_rel.name
                file_specs.append((str(src_rel), dest))
            print()

        n_ok, n_missing = fetch_remote_via_tar(
            ssh_target   = args.ssh_target,
            project_root = project_root,
            file_specs   = file_specs,
            out_dir      = out_dir,
            dry_run      = args.dry_run,
        )
        n_total = len(file_specs)

    # ---- Summary ----
    print()
    print(f"[summary] {n_ok}/{n_total} files copied"
          + (f"  ({n_missing} missing/failed)" if n_missing else ""))
    if n_missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
