import std.stdio;
import core.stdc.stdio : FILE, fclose, fopen;

void main()
{
    // echo -n "xxxxx" | od -A n -t x1
    writeln("Hello"); // 48 65 6c 6c 6f

    // Missing files are intentional: the preload hook observes the requested path.
    FILE* localisation = fopen("localisation/ui.yml", "r");
    FILE* font = fopen("assets/fonts/game.ttf", "r");
    FILE* unrelated = fopen("config/settings.txt", "r");
    if (localisation !is null) fclose(localisation);
    if (font !is null) fclose(font);
    if (unrelated !is null) fclose(unrelated);
}
