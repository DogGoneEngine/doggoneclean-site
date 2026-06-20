# Close the Laptop

> PARKED PLAN. Do not build until the trigger is met (see CLAUDE.md PARKED block).
> Stored verbatim. Building this now would violate its own first principle:
> revenue comes before the verification system, and Jake is not earning yet.

--- PLAN: CLOSE THE LAPTOP ---

Endgame, in one line: When everything's right, nothing happens and Paul opens
nothing. When something goes wrong, his phone pings him with the problem and a
one-tap fix. The board and the office verdict exist only for when he chooses to
look. Silence is the default state. That is the closed laptop.

THE ORDER (do not skip ahead):

1. Revenue (first, and already in motion outside this plan). Closed-laptop needs
   a business that earns first. Until Jake is running paid bath days in Clean,
   nothing below is built.

2. The gauges, read-only (right after launch). A read-only verification board:
   pricing, cadence, money, recent activity. Read off existing tables, no writes,
   no schema changes. Placement, decided:
     - Full board lives in the Clean admin, Back of House, next to Laelaps. It
       reads Clean's data and it's where Paul verifies.
     - The verdict (all quiet / N flags) lives on the Clean card in Mount
       Olympus, where the LIVE dot is. The office tells him which business needs
       him today. Tapping the count drops into the board.
   Ship as v1. Do not gold-plate.

3. The wiring (once the board has proven it can stay quiet). This is the step
   that actually closes the laptop, and it is connection, not construction. The
   other half already exists in dgc-prod: the briefings table (severity
   info/signal/alert, recommended_action, new -> approved -> acted -> resolved),
   agents, tasks with an action field, and the Hermes/Zeus Telegram pipe. The
   gauges are the missing sensor. Wire them so a loud gauge writes an alert
   briefing carrying its own fix, pings the phone, and resolves on one tap. The
   low-risk ones resolve themselves and just report after.

ONE SIGNAL, THREE FACES: A thing being off is one signal shown three ways: the
office verdict on Olympus (pull, on a glance), the admin board in Clean (pull,
on a drill-in), the phone push with a fix button (push, when it can't wait). A
quiet gauge writes no briefing. The gauges and the briefings system were never
two things; they're the eyes and the mouth of one thing.

THE DISCIPLINE: Don't build step 2 before Jake is earning. Don't build step 3
before the board has shown it can stay quiet. The gauges don't make money;
revenue does. Build the cockpit after the plane is carrying passengers.

--- END PLAN ---
