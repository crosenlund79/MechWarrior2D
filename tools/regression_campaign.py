#!/usr/bin/env python3
"""Runtime regression for the Kern-7 campaign, start to finish, in a real game process:
new game in Ersthafen (Greta's intro) → first outing → the burning car at the east gate → get out and
search it (Kern-7, Konrad, the recorder, Mika) → the Alter Eisback story hunt on the Wrackküste
(real gunfire) → Act II (Grauwacht, Oskar) → Act III → delivery in Stahlheim (paid, finale) → the
three transmitter masts on the Hochstraße (park + hold E) → the migration turns → Kaltvater (real
gunfire) → ending slides + credits → keep hunting in the open world → save, quit, reload.

Travel between nodes uses the travel command (the route network and gates are covered by
regression_hunt.py); fights use the real weapons with lowered creature health to keep the run short.
  python3 tools/regression_campaign.py     exit 0 = pass"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hs_driver import Instance

HEADLESS = os.environ.get("HS_WINDOWED") != "1"
fails = []


def check(cond, what):
    print(("  ok   " if cond else "  FAIL ") + what)
    if not cond:
        fails.append(what)


g = Instance("campaign", headless=HEADLESS)
g.wipe(); g.start()
try:
    print("1. a new Jäger in Ersthafen")
    st = g.cmd("new 1")["state"]
    g.cmd("wait 0.5"); st = g.state()
    check(st["card_showing"] or len(st["story_cards"]) > 0, "Greta's intro card is shown")
    check(st["story"]["objective"].get("text") == "OBJ_FIRST_JOB", "objective: take a job")
    g.cmd("story cards")
    st = g.cmd("contract accept hunt:skirr")["state"]
    check(any(c["id"] for c in st["contracts"]["active"]), "a contract taken from the board")

    print("2. first outing and the burning car")
    g.cmd("travel taubecken"); g.cmd("wait 0.5")
    st = g.state()
    check(st["story"]["flags"].get("visited_territory"), "first outing into a territory")
    g.cmd("travel ersthafen"); g.cmd("wait 0.8")
    st = g.state()
    check(st["story"]["flags"].get("wreck_arrived") and "konrad_wreck" in st["pois"], "the burning car is at the east gate")
    check(st["card_showing"] or len(st["story_cards"]) > 0, "Greta raises the alarm")
    g.cmd("story cards")
    import json
    loc = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data/locations/ersthafen.json")))
    wp = [p for p in loc["pois"] if p["id"] == "konrad_wreck"][0]["pos"]
    g.cmd(f"set_mech {wp[0]} {wp[1] + 320} 0"); g.cmd("wait 0.3")
    g.cmd("interact")
    g.cmd(f"walk_to {wp[0] - 60} {wp[1] + 110} 15")
    r = g.cmd("interact"); g.cmd("wait_task"); g.cmd("wait 0.3")
    st = g.state()
    check(st["story"]["flags"].get("kern7_received"), "searched the wreck: Kern-7 received")
    spk = [c.get("speaker") for c in st["story_cards"]]
    check("konrad" in spk and "mika" in spk, f"Konrad's last words and Mika's offer ({spk})")
    check(any(c["id"] == "ct_alt_eisback" for c in st["contracts"]["active"]), "the Alter Eisback story contract is active")
    g.cmd("story cards")
    g.cmd(f"walk_to {wp[0] - 90} {wp[1] + 320} 15"); g.cmd("interact")

    print("3. the Alter Eisback (Act I hunt)")
    g.cmd("travel wrackkueste"); g.cmd("wait 0.8"); g.cmd("story cards")
    st = g.state()
    eb = st["game"]["creatures"].get("eisback_alt")
    check(eb is not None, "the Alter Eisback is on the Wrackküste")
    g.cmd("devx upgrade weapons"); g.cmd("devx repair"); g.cmd("dev toggle invulnerable")
    g.cmd(f"set_mech {eb['pos'][0] - 520:.0f} {eb['pos'][1]:.0f} 90"); g.cmd("wait 0.3")
    g.cmd("creature_hp 60 cid=eisback_alt")
    for _ in range(8):
        g.cmd("fire_at_creature 3 body cid=eisback_alt")
        if g.state()["game"]["creatures"]["eisback_alt"]["ai"] == "dead":
            break
    st = g.state()
    check(st["game"]["creatures"]["eisback_alt"]["ai"] == "dead", "brought down with the roof guns")
    check(st["story"]["flags"].get("act1_hunt_done"), "Act I hunt complete")
    g.cmd("story cards")
    g.cmd("travel ersthafen"); g.cmd("wait 0.5"); g.cmd("story cards")
    g.cmd("set_mech %d %d 180" % tuple(loc["garage"]["pos"])); g.cmd("wait 1.0")
    st = g.state()
    check(not any(c["id"] == "ct_alt_eisback" for c in st["contracts"]["active"]), "story contract paid out at the garage")

    print("4. Act II and III")
    for n in ("taubecken", "rostfeld", "grauwacht"):
        g.cmd(f"travel {n}"); g.cmd("wait 0.4"); g.cmd("story cards")
    st = g.state()
    check(st["story"]["act"] == 2 and st["node"] == "grauwacht", f"Act II in Grauwacht (act {st['story']['act']})")
    check(any(c["id"] == "ct_junker_crew" for c in st["contracts"]["active"]), "Oskar's Junker job")
    for n in ("dornpass", "eisenfurt", "glaswueste"):
        g.cmd(f"travel {n}"); g.cmd("wait 0.4"); g.cmd("story cards")
    st = g.state()
    check(st["story"]["flags"].get("henrik_briefed"), "Henrik read the case in Eisenfurt")
    check("research_station" in st["pois"], "the research station is in the Glaswüste")
    gl = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data/locations/glaswueste.json")))
    sp = [p for p in gl["pois"] if p["id"] == "research_station"][0]["pos"]
    g.cmd(f"set_mech {sp[0]} {sp[1] + 320} 0"); g.cmd("wait 0.3"); g.cmd("interact")
    g.cmd(f"walk_to {sp[0] - 60} {sp[1] + 110} 15"); g.cmd("interact"); g.cmd("wait_task"); g.cmd("wait 0.3")
    st = g.state()
    check(st["story"]["flags"].get("truth_known"), "Ilse explains Kern-7 and the migration")
    g.cmd("story cards")
    g.cmd(f"walk_to {sp[0] - 90} {sp[1] + 320} 15"); g.cmd("interact")
    for n in ("glutfeld", "frostgrund", "hochstrasse"):
        g.cmd(f"travel {n}"); g.cmd("wait 0.4"); g.cmd("story cards")
    st = g.state()
    check(st["story"]["act"] == 3, "Act III on the last road")

    print("5. delivery in Stahlheim")
    m0 = st["money"]
    g.cmd("travel stahlheim"); g.cmd("wait 0.5")
    st = g.state()
    check(st["story"]["flags"].get("kern7_delivered") and st["money"] > m0 + 5000, f"Kern-7 delivered and paid ({m0} → {st['money']})")
    check(st["zone_status"] == "safe", "Stahlheim is not cleared yet")
    check(st["story"]["objective"].get("text") == "OBJ_TRANSMITTERS", "the finale: restart the masts")
    g.cmd("story cards")

    print("6. the transmitters and Kaltvater")
    g.cmd("travel hochstrasse"); g.cmd("wait 0.8"); g.cmd("story cards")
    hs = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data/locations/hochstrasse.json")))
    for p in [p for p in hs["pois"] if p["kind"] == "transmitter"]:
        g.cmd(f"set_mech {p['pos'][0] - 160} {p['pos'][1]} 90"); g.cmd("wait 0.3")
        r = g.cmd("interact"); g.cmd("wait 4.6")
        g.cmd("story cards")
    st = g.state()
    check(st["story"]["flags"].get("transmitters_on"), f"all three masts restarted ({st['story']['activated']})")
    kv = st["game"]["creatures"].get("kaltvater")
    check(kv is not None, "Kaltvater has come down the highway")
    div = [k for k, c in st["game"]["creatures"].items() if k.startswith("migration_") and c.get("diverted")]
    check(len(div) >= 5, f"the migration turns away ({len(div)})")
    g.cmd("weapon mg")
    g.cmd(f"set_mech {kv['pos'][0] - 700:.0f} {kv['pos'][1]:.0f} 90"); g.cmd("wait 0.3")
    g.cmd("devx fuel"); g.cmd("devx repair")
    g.cmd("creature_hp 40 cid=kaltvater")
    for _ in range(20):
        r = g.cmd("fire_at_creature 3 body cid=kaltvater")
        k = r["state"]["game"]["creatures"]["kaltvater"]
        m = r["state"]["game"]["mech"]; print(f"       (Kaltvater {k['ai']} hp {k['hp']:.0f}, ammo {r['state']['ammo']}, mode {r['state']['game']['mode']}, engine {m['engine']}, hull {m['integrity']:.0f}, task {r['state'].get('task')})")
        if k["ai"] == "dead":
            break
    g.cmd("wait 0.5")
    st = g.state()
    check(st["game"]["creatures"]["kaltvater"]["ai"] == "dead", "Kaltvater is down")
    check(st["story"]["flags"].get("campaign_complete") and st["story"]["act"] == 4, "the campaign is complete")

    print("7. ending, credits, and the open world")
    for _ in range(12):
        st = g.cmd("wait 0.3")["state"]
        if st["ending_up"]:
            break
        g.cmd("story cards")
    check(st["ending_up"], "the ending slides and credits roll")
    g.cmd("ending"); g.cmd("wait 0.3")
    st = g.state()
    check(not st["ending_up"] and not st["paused"], "keep hunting: back in the game")
    g.cmd("travel stahlheim"); g.cmd("wait 0.5"); g.cmd("story cards")
    st = g.state()
    check(st["zone_status"] == "cleared", "Stahlheim CLEARED")
    g.cmd("save"); g.quit(); g.start()
    st = g.cmd("continue 1")["state"]
    check(st["story"]["flags"].get("campaign_complete") and st["node"] == "stahlheim" and st["zone_status"] == "cleared", "the finished campaign persists")
    check(len(st["story_cards"]) == 0, "no story cards replay after loading")
finally:
    g.quit()
print("\nRESULT:", "PASS" if not fails else f"FAIL ({len(fails)})")
sys.exit(1 if fails else 0)
