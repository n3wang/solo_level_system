# Album Image Mappings for Lofi Tracks

This document describes the manually curated album image mappings for the 41 lofi tracks.

## Album Images Available
- `al1-lofigirl.png` - Classic lofi girl studying
- `al02-lofistudybook.png` - Study/book theme
- `al04-spacecontrols.png` - Sci-fi control panel
- `al04-spacedesign.png` - Space design theme
- `al05-paranormal.png` - Paranormal/mysterious theme
- `al05-spaceexploration.png` - Space exploration
- `al06-haunted.png` - Dark/haunted theme
- `al08-electronics.png` - Electronic/tech theme
- `al09-80s.png` - 80s retro theme
- `al10-willsmith.png` - Hero/action theme
- `al11-sports.png` - Sports/fitness theme
- `al12-sports.png` - Alternative sports theme
- `al13-commercial.png` - Commercial/business theme
- `al14-album.png` - Generic album cover
- `al15-happyplace.png` - Happy/peaceful theme
- `al16-chaos.png` - Chaos/intensity theme
- `al16-spaceship.png` - Spaceship/sci-fi theme
- `al16-wind.png` - Natural/wind theme
- `a07-elecctronics.png` - Alternative electronics theme

## Mapping Strategy

### Theme-Based Mappings
1. **80s/Retro Themes** → `al09-80s.png`
   - Lady Of The 80's, Neon Nights, Smooth 80s, A Hero Of The 80s, Neon Adventure Deep Fashion House, Cqb Tense 80s Synthwave Instrumental

2. **Study/Lofi Themes** → `al02-lofistudybook.png` or `al1-lofigirl.png`
   - Study tracks, peaceful lofi, memories, and classic lofi tracks

3. **Sports/Fitness** → `al11-sports.png`
   - Sports Gym Fitness Synthwave Phonk Music

4. **Space/Sci-Fi** → `al05-spaceexploration.png`, `al04-spacecontrols.png`, `al16-spaceship.png`
   - Mezhdunami Voyager, Interstellar Life, space-related scientific research

5. **Electronics/Tech** → `al08-electronics.png`, `a07-elecctronics.png`
   - Electronic music, science technology, doctor science themes

6. **Dark/Mysterious** → `al06-haunted.png`, `al05-paranormal.png`
   - Dark Academia Melancholy, The Best Detective, Stranger Things, Resurrection

7. **Nature/Wind** → `al16-wind.png`
   - Ghibli Style tracks (inspired by Studio Ghibli's nature themes)

8. **Happy/Peaceful** → `al15-happyplace.png`
   - Calm peaceful tracks, happy places, positive themes

9. **Commercial/Fashion** → `al13-commercial.png`
   - London Fashion Week, Balenciaga Trap Music, commercial themes

10. **Chaos/Intensity** → `al16-chaos.png`
    - Shattered (representing broken/chaotic themes)

11. **Hero/Action** → `al10-willsmith.png`
    - A Hero Of The 80s (action hero theme)

## Complete Track-to-Image Mapping

| Track ID | Title | Album Image |
|----------|-------|-------------|
| 1 | Lady Of The 80's | al09-80s.png |
| 2 | Neon Nights | al09-80s.png |
| 3 | Sports Gym Fitness... | al11-sports.png |
| 4 | High Rise | al13-commercial.png |
| 5 | Lofi Study Calm... | al02-lofistudybook.png |
| 6 | Study | al02-lofistudybook.png |
| 7 | Lofi Study Calm... | al15-happyplace.png |
| 8 | Relaxing Ambient... | al1-lofigirl.png |
| 9 | Dark Academia... | al06-haunted.png |
| 10 | Cops First Day... | al13-commercial.png |
| 11 | Mezhdunami Voyager | al05-spaceexploration.png |
| 12 | The People's Land | al15-happyplace.png |
| 13 | Ghibli Style 1 | al16-wind.png |
| 14 | Days For You | al15-happyplace.png |
| 15 | Ghibli Style 2 | al16-wind.png |
| 16 | Thought | al1-lofigirl.png |
| 17 | The Best Detective | al06-haunted.png |
| 18 | Singularity Abstract... | al08-electronics.png |
| 19 | Awake The Science... | a07-elecctronics.png |
| 20 | Lo Fi For The Best... | al14-album.png |
| 21 | Lofi Soul | al1-lofigirl.png |
| 22 | A New Scientific... | al04-spacecontrols.png |
| 23 | London Fashion Week | al13-commercial.png |
| 24 | Resurrection | al05-paranormal.png |
| 25 | The World Of Science | al04-spacedesign.png |
| 26 | Secret Lab | al04-spacecontrols.png |
| 27 | Doctor Science... | a07-elecctronics.png |
| 28 | Shattered | al16-chaos.png |
| 29 | Cqb Tense 80s... | al09-80s.png |
| 30 | A Hero Of The 80s | al10-willsmith.png |
| 31 | Balenciaga Trap... | al13-commercial.png |
| 32 | Neon Adventure... | al09-80s.png |
| 33 | Smooth 80s | al09-80s.png |
| 34 | Memories Retro Lofi | al1-lofigirl.png |
| 35 | Retro Dreams... | al1-lofigirl.png |
| 36 | Interstellar Life | al16-spaceship.png |
| 37 | Stranger Things | al05-paranormal.png |
| 38-41 | Lofi (tracks 1-4) | al1-lofigirl.png |

## Usage in Code

The album images are now accessible in the LofiTrack model:

```dart
final track = await LofiService.getTrackById(1);
print(track.albumImage); // "album/al09-80s.png"
print(track.albumImagePath); // "assets/album/al09-80s.png"
```

## Future Maintenance

When adding new tracks, the automated script (`lofi_organizer.dart`) includes theme-based album image selection that will automatically assign appropriate images based on track titles and themes.