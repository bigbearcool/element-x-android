// Minimal NAPI async bridge. Compiled only if the OpenHarmony sysroot
// provides napi/native_api.h. This is not an ArkTS application and it is
// not loaded by a HarmonyOS runtime in this environment.

#include "napi/native_api.h"

#include <cstdlib>
#include <cstring>

extern "C" uint32_t hm_poc_add(uint32_t a, uint32_t b);

struct AsyncAdd {
    napi_async_work work;
    napi_deferred deferred;
    uint32_t a;
    uint32_t b;
    uint32_t sum;
};

static void Execute(napi_env env, void *data) {
    (void)env;
    auto *task = static_cast<AsyncAdd *>(data);
    task->sum = hm_poc_add(task->a, task->b);
}

static void Complete(napi_env env, napi_status status, void *data) {
    auto *task = static_cast<AsyncAdd *>(data);
    if (status == napi_ok) {
        napi_value out;
        napi_create_uint32(env, task->sum, &out);
        napi_resolve_deferred(env, task->deferred, out);
    } else {
        napi_value msg;
        napi_create_string_utf8(env, "hm_poc async work failed", NAPI_AUTO_LENGTH, &msg);
        napi_value err;
        napi_create_error(env, nullptr, msg, &err);
        napi_reject_deferred(env, task->deferred, err);
    }
    napi_delete_async_work(env, task->work);
    delete task;
}

static napi_value AddAsync(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    auto *task = new AsyncAdd();
    task->work = nullptr;
    task->deferred = nullptr;
    task->a = 0;
    task->b = 0;
    task->sum = 0;
    napi_get_value_uint32(env, args[0], &task->a);
    napi_get_value_uint32(env, args[1], &task->b);

    napi_value promise;
    napi_create_promise(env, &task->deferred, &promise);

    napi_value name;
    napi_create_string_utf8(env, "hmPocAddAsync", NAPI_AUTO_LENGTH, &name);
    napi_create_async_work(env, nullptr, name, Execute, Complete, task, &task->work);
    napi_queue_async_work(env, task->work);
    return promise;
}

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"addAsync", nullptr, AddAsync, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "hm_poc",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void hm_poc_register_napi(void) {
    napi_module_register(&g_module);
}
