"""Drive real Thawborn game processes through the --autotest command channel.

Each Instance is a separate Godot process with its own user folder
(--instance=<name>). Commands are appended to autotest_inbox.txt; results are
read from autotest_outbox.json. See src/dev/autotest_driver.gd.
"""
import json, os, shutil, subprocess, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "godot")
USER_DIR = os.environ.get("HS_USER_DIR", os.path.expanduser("~/.local/share/Thawborn"))
LOG_DIR = os.path.join(ROOT, "tests", "_out")


class Instance:
    def __init__(self, name, headless=True, extra_args=None):
        self.name, self.headless, self.extra = name, headless, extra_args or []
        self.root = os.path.join(USER_DIR, "instances", name)
        self.proc, self.seq = None, 0

    inbox = property(lambda s: os.path.join(s.root, "autotest_inbox.txt"))
    outbox = property(lambda s: os.path.join(s.root, "autotest_outbox.json"))

    def wipe(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def start(self, timeout=60):
        os.makedirs(self.root, exist_ok=True)
        for p in (self.inbox, self.outbox):
            if os.path.exists(p):
                os.remove(p)
        os.makedirs(LOG_DIR, exist_ok=True)
        args = [GODOT] + (["--headless"] if self.headless else []) + ["--path", ROOT] + self.extra
        args += ["--", f"--instance={self.name}", "--autotest"]
        self.log = open(os.path.join(LOG_DIR, f"{self.name}.log"), "a")
        self.log.write(f"\n===== start {time.ctime()} {' '.join(args)}\n"); self.log.flush()
        self.proc = subprocess.Popen(args, stdout=self.log, stderr=subprocess.STDOUT)
        self.seq = 0
        self._wait(0, timeout)
        return self

    def _wait(self, seq, timeout):
        end = time.time() + timeout
        while time.time() < end:
            if self.proc.poll() is not None and not os.path.exists(self.outbox):
                raise RuntimeError(f"{self.name}: process exited ({self.proc.returncode})")
            try:
                with open(self.outbox) as f:
                    d = json.load(f)
                if d.get("seq") == seq:
                    return d
            except (OSError, ValueError):
                pass
            time.sleep(0.05)
        raise TimeoutError(f"{self.name}: no answer for seq {seq}")

    def cmd(self, line, timeout=90):
        with open(self.inbox, "a") as f:
            f.write(line + "\n")
        self.seq += 1
        return self._wait(self.seq, timeout)

    def state(self):
        return self.cmd("wait 0")["state"]

    def quit(self, timeout=20):
        if self.proc and self.proc.poll() is None:
            try:
                self.cmd("quit", timeout=timeout)
            except Exception:
                pass
            try:
                self.proc.wait(timeout)
            except subprocess.TimeoutExpired:
                self.proc.kill()
