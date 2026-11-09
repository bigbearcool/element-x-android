// Minimal NAPI wrapper around hm_sdk_open_encrypted_store.
// The HarmonyOS runtime is not present here, so this file is only linked.

#include "napi/native_api.h"

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

extern "C" int hm_sdk_open_encrypted_store(const char *path, const uint8_t *key, size_t key_len);
extern "C" size_t hm_sdk_store_key_len(void);

struct OpenTask {
    napi_async_work work;
    napi_deferred deferred;
    std::string path;
    uint8_t key[32];
    int result;
};

static void Execute(napi_env env, void *data) {
    (void)env;
    auto *task = static_cast<OpenTask *>(data);
    task->result = hm_sdk_open_encrypted_store(task->path.c_str(), task->key, sizeof(task->key));
}

static void Complete(napi_env env, napi_status status, void *data) {
    auto *task = static_cast<OpenTask *>(data);
    if (status == napi_ok) {
        napi_value out;
        napi_create_int32(env, task->result, &out);
        napi_resolve_deferred(env, task->deferred, out);
    } else {
        napi_value msg;
        napi_create_string_utf8(env, "sdk diag async work failed", NAPI_AUTO_LENGTH, &msg);
        napi_value err;
        napi_create_error(env, nullptr, msg, &err);
        napi_reject_deferred(env, task->deferred, err);
    }
    napi_delete_async_work(env, task->work);
    delete task;
}

static napi_value OpenEncryptedStore(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    auto *task = new OpenTask();
    task->work = nullptr;
    task->deferred = nullptr;
    task->result = -1;
    std::memset(task->key, 0, sizeof(task->key));

    size_t path_len = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &path_len);
    std::vector<char> path_buf(path_len + 1);
    napi_get_value_string_utf8(env, args[0], path_buf.data(), path_buf.size(), &path_len);
    task->path.assign(path_buf.data(), path_len);

    bool is_typedarray = false;
    napi_is_typedarray(env, args[1], &is_typedarray);
    if (!is_typedarray || hm_sdk_store_key_len() != 32) {
        delete task;
        napi_value out;
        napi_create_int32(env, -2, &out);
        return out;
    }
    napi_typedarray_type array_type;
    size_t length = 0;
    void *data = nullptr;
    napi_value buffer;
    size_t offset = 0;
    napi_get_typedarray_info(env, args[1], &array_type, &length, &data, &buffer, &offset);
    if (data == nullptr || length != 32) {
        delete task;
        napi_value out;
        napi_create_int32(env, -2, &out);
        return out;
    }
    std::memcpy(task->key, data, 32);

    napi_value promise;
    napi_create_promise(env, &task->deferred, &promise);
    napi_value name;
    napi_create_string_utf8(env, "hmSdkOpenEncryptedStore", NAPI_AUTO_LENGTH, &name);
    napi_create_async_work(env, nullptr, name, Execute, Complete, task, &task->work);
    napi_queue_async_work(env, task->work);
    return promise;
}

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"openEncryptedStore", nullptr, OpenEncryptedStore, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "hm_sdk_diag",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void hm_sdk_diag_register(void) {
    napi_module_register(&g_module);
}
