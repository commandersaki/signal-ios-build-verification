"""Re-run the actool command logged by an Xcode build for the main app catalog, sending all outputs to <outdir>.

Used to test whether the Simulator runtime explains asset rasterisation differences.
Usage: rerun_actool.py <file holding the logged actool command line> <outdir>
"""
import os, shlex, subprocess, sys
cmd_line, outdir = open(sys.argv[1]).read().strip(), sys.argv[2]
args = shlex.split(cmd_line)
os.makedirs(outdir, exist_ok=True)
redirect = {"--compile": outdir, "--output-partial-info-plist": os.path.join(outdir, "partial.plist"),
            "--export-dependency-info": os.path.join(outdir, "deps.txt")}
for i, a in enumerate(args):
    if a in redirect: args[i + 1] = redirect[a]
r = subprocess.run(args, cwd="/Volumes/workspace/repository", capture_output=True, text=True,
                   env={**os.environ, "DEVELOPER_DIR": "/Applications/Xcode-26.5.0.app/Contents/Developer"})
print("actool exit", r.returncode); print("\n".join(l for l in (r.stderr or "").splitlines() if "SimulatorAgent" in l or "runtime" in l.lower())[:600])
