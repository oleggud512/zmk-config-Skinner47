#define DT_DRV_COMPAT zmk_behavior_set_os

#include <zephyr/device.h>
#include <drivers/behavior.h>
#include <zmk/behavior.h>
#include "os_state.h"

struct behavior_set_os_config
{
};
struct behavior_set_os_data
{
};

static int on_keymap_binding_pressed(struct zmk_behavior_binding *binding,
                                     struct zmk_behavior_binding_event event)
{
    set_os((uint8_t)binding->param1);
    return ZMK_BEHAVIOR_OPAQUE;
}

static int on_keymap_binding_released(struct zmk_behavior_binding *binding,
                                      struct zmk_behavior_binding_event event)
{
    return ZMK_BEHAVIOR_OPAQUE;
}

static const struct behavior_driver_api behavior_set_os_driver_api = {
    .binding_pressed = on_keymap_binding_pressed,
    .binding_released = on_keymap_binding_released,
};

#define SET_OS_INST(n)                                                        \
    static struct behavior_set_os_config config_##n = {};                     \
    static struct behavior_set_os_data data_##n = {};                         \
    BEHAVIOR_DT_INST_DEFINE(n, NULL, NULL, &data_##n, &config_##n,            \
                            POST_KERNEL, CONFIG_KERNEL_INIT_PRIORITY_DEFAULT, \
                            &behavior_set_os_driver_api);

DT_INST_FOREACH_STATUS_OKAY(SET_OS_INST)