# HDRCheck

Can be built with Visual Studio 2022. If you're on linux it shouldn't be too hard to adapt for your platform, it's one CPP file.
After building the DLL simply copy it to mpv script folder together with auto_hdr.lua. Change the path to your script folder inside the lua script, you can also adjust or add/remove any specific mpv settings you want inside the script. By default logging to file in the same folder is enabled, run MPV and verify everything works in the file, then you can disable logging.
