# Google Play listing: Glide Home

## App details

- **App name** (30 characters max): `Glide Home: Paper Plane`
- **Short description** (80 characters max): `Fold, throw and glide a paper plane across a cozy golden-hour town.`
- **Category:** Games > Casual
- **Tags:** Casual, Flight, Relaxing, Single player, Offline
- **Price:** Free. No ads and no in-app purchases.

## Full description

> A kid on a balcony folds a sheet of notebook paper, takes aim, and throws.
>
> Glide Home is a calm flying game about one paper plane and a sleepy golden-hour town. Your plane is always sinking slowly, so the skill is in reading the air:
>
> • Dive to pick up speed, then pull up to trade it for height
> • Find shimmering green rising air and ride it to climb
> • Follow the dotted line and fly through the blue rings
> • Settle down softly on the target for a Feather landing
>
> SEVEN HANDCRAFTED FLIGHTS
> • **Window to the Picnic:** from an upstairs balcony to a picnic blanket in the park
> • **Under the Old Bridge:** skim the river and thread the plane under a stone arch
> • **Up to the Clock Tower:** slip through the Mill Lane archway, skim the millpond under a footbridge, fly through a flower shop and over the rooftops to a tiny balcony
> • **Classroom Window Escape:** launch from your desk, dodge the ceiling fan, slip out the window, under the school pond's bridge and down the lane to the bus stop
> • **Lantern Night:** at dusk, weave over and under the lantern strings, thread the old bridge's arch and land on a lantern raft
> • **Open House Day:** fly room to room through open windows and doors, down a stairwell and onto the cat's rug
> • **Willow Close:** from a treehouse, swoop through a library, over a car in a garage, up a stairwell and into the dog's bed
>
> MAKE IT YOURS
> Earn ribbons for soft, accurate landings and unlock new papers (graph paper, red origami, old map, newspaper and more), trails (rainbow ribbon, gold sparkles, confetti, comet glow) and wing stickers.
>
> COZY BY DESIGN
> • Warm, hand-made look with falling leaves, birds, ducks and a fountain
> • Gentle generated music and wind
> • Play in portrait or landscape, with touch, gamepad or keyboard
> • No ads, no accounts, no internet needed, no data collected

## Graphics checklist

- [x] App icon 512×512: `icons/icon_512.png`
- [ ] Feature graphic 1024×500: `store/feature_graphic.png` (generated; check it before uploading)
- [ ] Phone screenshots, 2 to 8, 9:16: `store/screenshots/phone_*.png`
- [ ] Optional 7" and 10" tablet screenshots: you can reuse the landscape shots `store/screenshots/landscape_*.png`

## Play Console answers

- **Privacy policy URL:** host `PRIVACY.md` publicly (for example GitHub Pages or a Google Site) and paste the link.
- **Ads:** No.
- **App access:** All functionality is available without special access.
- **Content rating (IARC questionnaire):** no violence, no fear, no language, no gambling, no user interaction, no data sharing. Expected rating: Everyone / PEGI 3.
- **Data safety:** "No data collected" and "No data shared". The app does not use encryption for network traffic because it makes no network requests.
- **Target audience:** If you include ages under 13, the game must meet the Families policy. It already does: no ads, no data collection and no external links. Choose the age groups deliberately, because including children triggers extra review.
- **Permissions:** VIBRATE only, for haptics.

## Release steps

1. In `autoload/game.gd`, set `UNLOCK_ALL_FOR_TESTING` to `false` so flights and Hangar items unlock normally.
2. In Godot, choose *Project > Install Android Build Template*. The preset uses a Gradle build to produce an AAB.
3. Create an upload keystore once and keep it safe:

   ```
   keytool -genkey -v -keystore glidehome-upload.keystore -alias glidehome -keyalg RSA -keysize 2048 -validity 10000
   ```

4. In *Project > Export > Android > Options > Keystore*, set Release, Release User and Release Password. Godot stores these outside the repo, in `.godot/export_credentials.cfg`.
5. Set *Version > Code* (for example 1, then 2, 3...) and *Version > Name* (for example 1.0.0).
6. Click *Export Project* with *Export With Debug* off to create `export/GlideHome.aab`.
7. In Play Console, create the app, enable Play App Signing, then upload the AAB to an **Internal testing** track first.
8. Test on two or three real phones, ideally one older and slower. Then promote to Closed or Production.
