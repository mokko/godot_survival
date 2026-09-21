# Where the save lives

`world/savegame.gd` writes one JSON file to `user://savegame.json`, and nothing else in the game
persists. What `user://` **is** comes from `project.godot`: `config/use_custom_user_dir` +
`config/custom_user_dir_name="Nakamoto"` pin the folder name, deliberately **not** the display title,
so renaming the game cannot move the save — but for **player builds only**: the engine forces the
default `app_userdata/<project name>` location for editor and `--script` runs, so the test suite never
sees the custom path. A **snap refresh** is a separate matter and still starts a fresh directory,
because the snap sets `XDG_DATA_HOME` per revision; surviving that needs the save to be adopted at
boot. On any machine, ask the engine rather than trusting a path written down anywhere:
`OS.get_user_data_dir()`.
