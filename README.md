# JIRAMATY

A satirical, touch-first utility management game built with Godot 4. Run
Antananarivo's electricity and water services through a three-minute shift.

## Play

- Tap a marker or use **+ / −** to move between the regional grid, Antananarivo,
  and a quartier's house map. Mouse-wheel zoom also works on desktop.
- Tap a quartier to see its simulated local streets, 25 fictional customer
  accounts, and the distribution wires connecting those houses.
- Tap a house to inspect its account, cut or restore its electricity and water,
  collect overdue bills, or inspect an illegal hookup.
- Tap a regional asset to inspect it. Source failures reduce shared network
  capacity; they do not create unrelated generators in each quartier.
- Open **Fuel** to set the diesel monthly target, delivery frequency, and
  automatic ordering. Orders are paid when dispatched and arrive by tanker
  after a travel timer; diesel generators draw down the shared reserve.
- Rain sometimes triggers a satirical prompt asking whether to cut power
  everywhere. That action disconnects every quartier without inventing a fault.
- Dispatch a maintenance team to repair a failed source or local fault. Repairs
  take time, and the shared team has a return cooldown. Upgrading the team costs
  $240 and shortens repair time.
- Keep public patience and the treasury above zero until the shift ends.

The first screen keeps the controls quiet while the game unfolds through
progressive map detail. The best shift time is saved locally.

## Map and simulation notes

Facility and quartier markers use approximate geographic positions from public
sources. The regional screen is a stylized network diagram, not an engineering
map; its lines and the displayed network-share values are gameplay abstractions.
Quartier outlines, streets, individual house positions, customer accounts, and
account states are generated for the game and do not identify real households.
The Antananarivo network includes hydro, HFO, solar, and a clearly labeled
simulated diesel backup fleet. Diesel procurement is a gameplay abstraction;
it does not imply that the named HFO facilities burn diesel. JIRAMA's national
generation mix includes heavy fuel and diesel, hydro, and a smaller renewable
share, while Antananarivo's named Ambohimanambola and Mandroseza thermal plants
are modeled as HFO.

Locations were cross-checked against [JIRAMA's service description](https://www.jirama.mg/la-jirama/),
[the IMF's 2025 electricity-sector review](https://www.imf.org/-/media/files/publications/selected-issues-papers/2025/english/sipea2025026.pdf),
[World Bank/UNDRR grid context](https://www.cdri.world/upload/pages/1823026310124028_202502030902undrr_cdri_madagascar.pdf),
[Global Energy Monitor's Andekaleka entry](https://www.gem.wiki/Andekaleka_hydroelectric_plant),
[Global Energy Monitor's Ambohimanambola entry](https://www.gem.wiki/Ambohimanambola_%28Trigu%29_power_plant),
[JICA's Antananarivo infrastructure plan](https://openjicareport.jica.go.jp/pdf/12340725_04.pdf),
[the Ambatolampy solar project location](https://www.gem.wiki/Ambatolampy_solar_project),
[PLOS research on Mandroseza water supply](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0218698),
[the World Bank's PAAEP project material on other water stations](https://paaep.mg/resources/cariboost_files/P174477_20CGES_20AF_20for_20QAT_20review_disclosed_Project_2025_2002_2026.pdf),
and public map references for [Isotry](https://mapcarta.com/14473556),
[Analakely](https://mapcarta.com/14500152), and
[Ankorondrano](https://mapcarta.com/N844529035). Coordinates and named assets
should be reviewed with local experts before presenting the map as operational
or authoritative.

## Run

Open this folder in Godot 4 and run main.tscn (or press F6 while it is open).
The game uses built-in drawing and input APIs; it has no asset or plugin
dependencies. Mouse clicks and touchscreen taps are supported.
