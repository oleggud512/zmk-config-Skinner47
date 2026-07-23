#define DT_DRV_COMPAT zmk_behavior_os_switch

#include <zephyr/device.h>
#include <drivers/behavior.h>
#include <zmk/behavior.h>
#include "os_state.h"

struct os_switch_config
{
    struct zmk_behavior_binding mac_bindings;
    struct zmk_behavior_binding win_bindings;
    struct zmk_behavior_binding lin_bindings;
};

struct os_switch_data
{
    uint8_t pressed_lang; // Cache state to prevent sticky keys on release
};

static int invoke_target(const struct os_switch_config *cfg, uint8_t lang,
                         struct zmk_behavior_binding_event event, bool pressed)
{
    struct zmk_behavior_binding target;
    if (lang == 0)
        target = cfg->mac_bindings;
    else if (lang == 1)
        target = cfg->win_bindings;
    else
        target = cfg->lin_bindings;

    if (pressed)
    {
        return behavior_keymap_binding_pressed(&target, event);
    }
    else
    {
        return behavior_keymap_binding_released(&target, event);
    }
}

static int on_os_switch_pressed(struct zmk_behavior_binding *binding,
                                struct zmk_behavior_binding_event event)
{
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct os_switch_config *cfg = dev->config;
    struct os_switch_data *data = dev->data;

    data->pressed_lang = get_os();
    return invoke_target(cfg, data->pressed_lang, event, true);
}

static int on_os_switch_released(struct zmk_behavior_binding *binding,
                                 struct zmk_behavior_binding_event event)
{
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct os_switch_config *cfg = dev->config;
    struct os_switch_data *data = dev->data;

    return invoke_target(cfg, data->pressed_lang, event, false);
}

static const struct behavior_driver_api os_switch_driver_api = {
    .binding_pressed = on_os_switch_pressed,
    .binding_released = on_os_switch_released,
};

#define OS_SWITCH_EXTRACT_BINDING(prop, n)                                                         \
    {                                                                                              \
        .behavior_dev = DEVICE_DT_NAME(DT_PHANDLE_BY_IDX(DT_DRV_INST(n), prop, 0)),                \
        .param1 = COND_CODE_0(DT_PHA_HAS_CELL_AT_IDX(DT_DRV_INST(n), prop, 0, param1), (0),        \
                              (DT_PHA_BY_IDX(DT_DRV_INST(n), prop, 0, param1))),                   \
        .param2 = COND_CODE_0(DT_PHA_HAS_CELL_AT_IDX(DT_DRV_INST(n), prop, 0, param2), (0),        \
                              (DT_PHA_BY_IDX(DT_DRV_INST(n), prop, 0, param2))),                   \
    }

#define OS_SWITCH_INST(n)                                                            \
    static struct os_switch_data data_##n = {};                                      \
    static const struct os_switch_config config_##n = {                              \
        .mac_bindings = OS_SWITCH_EXTRACT_BINDING(mac_bindings, n),                  \
        .win_bindings = OS_SWITCH_EXTRACT_BINDING(win_bindings, n),                  \
        .lin_bindings = OS_SWITCH_EXTRACT_BINDING(lin_bindings, n),                  \
    };                                                                               \
    DEVICE_DT_INST_DEFINE(n, NULL, NULL, &data_##n, &config_##n,                     \
                          POST_KERNEL, CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,          \
                          &os_switch_driver_api);

DT_INST_FOREACH_STATUS_OKAY(OS_SWITCH_INST)