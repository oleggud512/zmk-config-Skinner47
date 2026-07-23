zephyr_library()
zephyr_library_include_directories(${ZEPHYR_BASE}/drivers)
zephyr_library_sources(
    src/os_state.c
    src/behavior_set_os.c
    src/behavior_os_switch.c
)