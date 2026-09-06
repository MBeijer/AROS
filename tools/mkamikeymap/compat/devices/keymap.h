#ifndef MKAKM_COMPAT_DEVICES_KEYMAP_H
#define MKAKM_COMPAT_DEVICES_KEYMAP_H

#include <exec/lists.h>

#define KCB_SHIFT       0
#define KCF_SHIFT       (1 << KCB_SHIFT)
#define KCB_ALT         1
#define KCF_ALT         (1 << KCB_ALT)
#define KCB_CONTROL     2
#define KCF_CONTROL     (1 << KCB_CONTROL)
#define KCB_DEAD        5
#define KCF_DEAD        (1 << KCB_DEAD)
#define KCB_STRING      6
#define KCF_STRING      (1 << KCB_STRING)
#define KCB_NOP         7
#define KCF_NOP         (1 << KCB_NOP)

#define KC_NOQUAL       0
#define KC_VANILLA      (KCF_CONTROL | KCF_ALT | KCF_SHIFT)

#endif
