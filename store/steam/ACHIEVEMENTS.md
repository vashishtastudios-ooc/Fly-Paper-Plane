# Steam achievements

Paper Plane Playground has 39 achievements. Enter each one in **Steamworks → Edit Steamworks Settings → Stats & Achievements → Achievements**, then press **Publish** on the Publish tab.

For every row:

- **API Name**: exactly as shown (the game unlocks achievements by this name; see `autoload/steam_service.gd`).
- **Display Name** and **Description**: as shown.
- **Set By**: Client.
- **Hidden**: only where marked (the description stays secret until it is unlocked).
- **Achieved icon**: `achievements/<API name>.png`. **Unachieved icon**: `achievements/<API name>_locked.png`. Both are 256×256 PNG.

Players keep achievements earned before Steam was added: the game re-unlocks them on Steam the first time it starts with the real App ID.

Icons are drawn by `make_icons.py` (run `python store/steam/make_icons.py` from the repo root). `achievement_sheet.png` shows them all at once.

| # | API Name | Display Name | Description | Hidden |
|---|---|---|---|---|
| 1 | `first_landing` | First touchdown | Land your first flight |  |
| 2 | `flight_school` | Flight school | Finish the flying lessons |  |
| 3 | `landings_25` | Frequent flyer | Land 25 times |  |
| 4 | `landings_100` | Seasoned pilot | Land 100 times |  |
| 5 | `bullseye` | Bullseye | Land right in the gold bullseye |  |
| 6 | `perfect_10` | Perfect ten | Earn 3 ribbons 10 times |  |
| 7 | `under_par_5` | Speedy | Land 5 different flights under par time |  |
| 8 | `dist_1k` | Kilometre club | Fly 1 km in total |  |
| 9 | `dist_10k` | Long hauler | Fly 10 km in total |  |
| 10 | `air_10m` | Head in the clouds | Spend 10 minutes in the air |  |
| 11 | `air_60m` | Sky dweller | Spend an hour in the air |  |
| 12 | `rings_100` | Ring master | Fly through 100 rings |  |
| 13 | `stars_100` | Star catcher | Collect 100 stars |  |
| 14 | `rolls_25` | Show-off | Do 25 barrel rolls |  |
| 15 | `thermals_50` | Thermal rider | Ride rising air 50 times |  |
| 16 | `gusts_100` | Puff power | Use 100 gusts |  |
| 17 | `skips_10` | Stone skipper | Skip off the water 10 times |  |
| 18 | `secrets` | Secret finder | Find both secret bonus rings | Yes |
| 19 | `linden_all` | Linden Lane local | Land every Linden Lane flight |  |
| 20 | `linden_gold` | Linden legend | 3 ribbons on every Linden Lane flight |  |
| 21 | `harbour_all` | Old sea dog | Land every Seaside Harbour flight |  |
| 22 | `harbour_gold` | Harbour hero | 3 ribbons on every Seaside Harbour flight |  |
| 23 | `trees_10` | Tree hugger | Crash into trees 10 times |  |
| 24 | `splash_10` | Paper boat | Splash into water 10 times |  |
| 25 | `crashes_100` | Never give up | Crash 100 times (and keep flying!) |  |
| 26 | `laundry_thief` | Laundry thief | Get tangled in the washing 5 times |  |
| 27 | `hole_in_one` | Hole in one | Land a bullseye on your very first try at a flight |  |
| 28 | `paper_cut` | Paper cut | Crash within a second of throwing |  |
| 29 | `running_on_fumes` | Running on fumes | Land with every gust used up |  |
| 30 | `show_off_supreme` | Show-off supreme | Do 3 barrel rolls in a single flight |  |
| 31 | `thread_the_needle` | Thread the needle | Fly through 20 rings in a row without missing one |  |
| 32 | `ghostbuster` | Ghostbuster | Land a flight faster than your own ghost |  |
| 33 | `say_cheese` | Say cheese! | Take a photo in photo mode |  |
| 34 | `sunday_flyer` | Sunday flyer | Spend 5 minutes in free flight |  |
| 35 | `encore` | Encore! | Land on the band's stage on Market Day |  |
| 36 | `basket_case` | Basket case | Land a bullseye in the laundry basket |  |
| 37 | `comeback_kid` | Comeback kid | Land a flight you have crashed on 10 times |  |
| 38 | `window_shopper` | Window shopper | Crash into a market stall or tent |  |
| 39 | `butter_landing` | Butter landing | Touch down so softly you barely notice |  |
