#!/usr/bin/env python3
"""Rendered verification + screenshots of the Kern-7 campaign in a real WINDOWED game (needs a display):
menu (creator prints + logo) → intro card → story card vs garage (waits) → Konrad's wreck → Alter Eisback
fight → act titles and cast cards → research station → delivery → masts at night → Kaltvater fight (quake
telegraph) → ending slides → credits → back in the game, Stahlheim CLEARED.
  xvfb-run -a -s "-screen 0 2600x1200x24" python3 tools/shots_campaign.py docs/screenshots/complete"""
import os, sys, json, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance, ROOT
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/complete")
os.makedirs(OUT, exist_ok=True)
fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


def loc(name):
    return json.load(open(os.path.join(ROOT, "data/locations/%s.json" % name)))


g = Instance("shots_campaign", headless=False, extra_args=["--rendering-driver", "opengl3"])
g.wipe(); g.start()


def shot(name):
    r = g.cmd(f"screenshot {OUT}/{name}.png")
    print("  shot", name, r["ok"])


def card_up(tries=20):
    for _ in range(tries):
        st = g.cmd("wait 0.2")["state"]
        if st["card_showing"]:
            return st
    return g.state()


def next_card():
    """Press E like a player to read the next card."""
    g.cmd("press interact"); g.cmd("wait 0.25")


def read_all(prefix=None, limit=12):
    n = 0
    while n < limit:
        st = g.state()
        if not st["card_showing"] and not st["story_cards"]:
            return
        if st["card_showing"] and prefix:
            shot(f"{prefix}_{n}")
        next_card(); n += 1


try:
    g.cmd("window 1600 900"); g.cmd("setting show_tutorial true"); g.cmd("wait 1.0")
    st = g.state()
    print("1. menu")
    check(st.get("menu_logo") == "bundled" and st.get("menu_prints") == ["bundled", "bundled"], "menu uses the creator's logo and both prints")
    shas = {f: hashlib.sha256(open(os.path.join(ROOT, "assets/Illustrations", f), "rb").read()).hexdigest()[:12]
            for f in ("Thawborn combat.png", "Thawborn garage.png", "Thawborn Logo.png")}
    print("       creator files:", shas)
    shot("c01_menu")

    print("2. intro: story card over the field guide")
    g.cmd("new 1"); st = card_up()
    check(st["card_showing"], "Greta's card is up")
    check(not st.get("help_visible", False), "the field guide stays hidden while a card is read")
    shot("c02_intro_card")
    read_all()
    st = g.state()
    check(not st["paused"], "reading the last card resumes the game")

    print("3. a card waits while the garage is open")
    g.cmd("ui garage on"); g.cmd("wait 0.3")
    g.cmd("story event arrive node=ersthafen")   # nothing (no outing yet) — then queue a real card:
    g.cmd("story flag visited_territory"); g.cmd("story event arrive node=ersthafen"); g.cmd("wait 0.6")
    st = g.state()
    check(not st["card_showing"] and len(st["story_cards"]) > 0, "a queued card waits while the garage is open")
    shot("c03_garage_with_card_waiting")
    g.cmd("ui garage off"); st = card_up()
    check(st["card_showing"], "...and shows once the garage closes")
    read_all()

    print("4. Konrad's wreck")
    wp = [p for p in loc("ersthafen")["pois"] if p["id"] == "konrad_wreck"][0]["pos"]
    g.cmd(f"set_mech {wp[0]} {wp[1] + 320} 0"); g.cmd("wait 0.8"); shot("c04_burning_car")
    g.cmd("interact"); g.cmd(f"walk_to {wp[0] - 60} {wp[1] + 110} 15"); g.cmd("interact"); g.cmd("wait_task")
    st = card_up()
    check(st["story"]["flags"].get("kern7_received"), "Kern-7 received")
    read_all("c05_konrad", 8)
    g.cmd(f"walk_to {wp[0] - 90} {wp[1] + 320} 15"); g.cmd("interact")

    print("5. the Alter Eisback")
    g.cmd("travel wrackkueste"); g.cmd("wait 0.6"); read_all()
    g.cmd("devx upgrade weapons"); g.cmd("devx upgrade armor"); g.cmd("devx upgrade armor"); g.cmd("devx upgrade cargo"); g.cmd("devx upgrade cooling")
    eb = g.state()["game"]["creatures"]["eisback_alt"]
    g.cmd(f"set_mech {eb['pos'][0] - 560:.0f} {eb['pos'][1]:.0f} 90"); g.cmd("wait 0.3"); g.cmd("dev toggle invulnerable")
    g.cmd("setting zoom 0.6")
    g.cmd("fire_at_creature 2.5 head cid=eisback_alt"); shot("c06_alter_eisback_fight")
    g.cmd("creature_hp 40 cid=eisback_alt")
    for _ in range(10):
        if g.cmd("fire_at_creature 2 body cid=eisback_alt")["state"]["game"]["creatures"]["eisback_alt"]["ai"] == "dead":
            break
    st = card_up(); read_all("c07_after_eisback", 4)
    check(g.state()["story"]["flags"].get("act1_hunt_done"), "Alter Eisback down")

    print("6. acts and cast")
    for n in ("taubecken", "rostfeld"):
        g.cmd(f"travel {n}"); g.cmd("wait 0.4"); read_all()
    g.cmd("travel grauwacht"); st = card_up()
    read_all("c08_act2_grauwacht", 5)
    for n in ("dornpass", "eisenfurt"):
        g.cmd(f"travel {n}"); g.cmd("wait 0.4"); read_all("c09_" + n, 4)
    g.cmd("travel glaswueste"); g.cmd("wait 0.4"); read_all()
    sp = [p for p in loc("glaswueste")["pois"] if p["id"] == "research_station"][0]["pos"]
    g.cmd(f"set_mech {sp[0]} {sp[1] + 320} 0"); g.cmd("wait 0.5"); shot("c10_research_station")
    g.cmd("interact"); g.cmd(f"walk_to {sp[0] - 60} {sp[1] + 110} 15"); g.cmd("interact"); g.cmd("wait_task")
    card_up(); read_all("c11_ilse", 4)
    g.cmd(f"walk_to {sp[0] - 90} {sp[1] + 320} 15"); g.cmd("interact")
    for n in ("glutfeld", "frostgrund", "hochstrasse"):
        g.cmd(f"travel {n}"); g.cmd("wait 0.4"); read_all("c12_" + n, 3)

    print("7. Stahlheim and the delivery")
    g.cmd("travel stahlheim"); card_up(); read_all("c13_aurich", 4)
    st = g.state()
    check(st["story"]["flags"].get("kern7_delivered"), "Kern-7 delivered")
    g.cmd("setting zoom 0.45"); g.cmd("wait 0.5"); shot("c14_stahlheim")

    print("8. the masts at night and Kaltvater")
    g.cmd("travel hochstrasse"); g.cmd("wait 0.5"); read_all()
    g.cmd("clock 23"); g.cmd("setting zoom 0.6")
    masts = [p for p in loc("hochstrasse")["pois"] if p["kind"] == "transmitter"]
    for i, p in enumerate(masts):
        g.cmd(f"set_mech {p['pos'][0] - 160} {p['pos'][1]} 90"); g.cmd("wait 0.4")
        g.cmd("interact"); g.cmd("wait 2.0")
        if i == 0:
            shot("c15_mast_restart_night")
        g.cmd("wait 2.6"); read_all("c16_mast_%d" % i, 3)
    st = g.state()
    check(st["story"]["flags"].get("transmitters_on") and "kaltvater" in st["game"]["creatures"], "masts running, Kaltvater arrives")
    g.cmd("clock 9"); g.cmd("devx repair"); g.cmd("devx upgrade weapons")
    kv = st["game"]["creatures"]["kaltvater"]
    g.cmd(f"set_mech {kv['pos'][0] - 760:.0f} {kv['pos'][1]:.0f} 90"); g.cmd("wait 0.3")
    got_quake = False
    for _ in range(20):
        st = g.cmd("fire_at_creature 1.0 body cid=kaltvater")["state"]
        tell = st["game"]["creatures"]["kaltvater"]["ai"]
        if tell == "quake_tell" and not got_quake:
            shot("c17_kaltvater_quake_telegraph"); got_quake = True
        if got_quake:
            break
    shot("c18_kaltvater_fight")
    g.cmd("creature_hp 40 cid=kaltvater")
    for _ in range(20):
        st = g.cmd("fire_at_creature 2 body cid=kaltvater")["state"]
        if st["game"]["creatures"]["kaltvater"]["ai"] == "dead":
            break
    check(st["game"]["creatures"]["kaltvater"]["ai"] == "dead", "Kaltvater is down")

    print("9. ending and credits")
    card_up(); read_all("c19_victory", 4)
    for _ in range(15):
        st = g.cmd("wait 0.3")["state"]
        if st["ending_up"]:
            break
    check(st["ending_up"], "the ending screen is up")
    g.cmd("wait 1.6")
    for i in range(4):
        shot(f"c20_ending_{i}")
        g.cmd("press interact"); g.cmd("wait 1.6")
    g.cmd("wait 3.5"); shot("c21_credits")
    g.cmd("wait 8"); shot("c22_credits_end")
    g.cmd("ending"); g.cmd("wait 0.5")
    st = g.state()
    check(not st["ending_up"] and not st["paused"], "keep hunting: back in the game")
    g.cmd("travel stahlheim"); g.cmd("wait 0.6"); read_all()
    st = g.state()
    check(st["zone_status"] == "cleared", "Stahlheim CLEARED")
    g.cmd("setting zoom 0.8"); g.cmd("wait 0.5"); shot("c23_stahlheim_cleared")
finally:
    g.quit()
print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
