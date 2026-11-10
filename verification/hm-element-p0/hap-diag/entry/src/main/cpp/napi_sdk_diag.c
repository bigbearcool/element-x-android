#include "napi/native_api.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern int hm_sdk_open_encrypted_store(const char *path, const uint8_t *key, size_t key_len);
extern size_t hm_sdk_store_key_len(void);

typedef struct OpenTask {
    napi_async_work work;
    napi_deferred deferred;
    char *path;
    uint8_t key[32];
    int result;
} OpenTask;

static void Execute(napi_env env, void *data)
{
    OpenTask *task = data;
    (void)env;
    task->result = hm_sdk_open_encrypted_store(task->path, task->key, sizeof(task->key));
}

static void Complete(napi_env env, napi_status status, void *data)
{
    OpenTask *task = data;
    if (status == napi_ok) {
        napi_value out;
        napi_create_int32(env, task->result, &out);
        napi_resolve_deferred(env, task->deferred, out);
    } else {
        napi_value message;
        napi_value error;
        napi_create_string_utf8(env, "sdk diag async work failed", NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, NULL, message, &error);
        napi_reject_deferred(env, task->deferred, error);
    }
    napi_delete_async_work(env, task->work);
    free(task->path);
    free(task);
}

static napi_value RejectSync(napi_env env, int code)
{
    napi_value out;
    napi_create_int32(env, code, &out);
    return out;
}

static napi_value OpenEncryptedStore(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {NULL, NULL};
    size_t path_len = 0;
    OpenTask *task;
    napi_typedarray_type array_type;
    size_t length = 0;
    void *data = NULL;
    napi_value buffer;
    size_t offset = 0;
    napi_value promise;
    napi_value name;

    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    if (hm_sdk_store_key_len() != 32) {
        return RejectSync(env, -2);
    }
    task = calloc(1, sizeof(*task));
    if (task == NULL) {
        return RejectSync(env, -4);
    }
    napi_get_value_string_utf8(env, args[0], NULL, 0, &path_len);
    task->path = malloc(path_len + 1);
    if (task->path == NULL) {
        free(task);
        return RejectSync(env, -4);
    }
    napi_get_value_string_utf8(env, args[0], task->path, path_len + 1, &path_len);
    if (napi_get_typedarray_info(env, args[1], &array_type, &length, &data, &buffer, &offset) != napi_ok ||
        data == NULL || length != 32) {
        free(task->path);
        free(task);
        return RejectSync(env, -2);
    }
    memcpy(task->key, data, 32);
    napi_create_promise(env, &task->deferred, &promise);
    napi_create_string_utf8(env, "hmSdkOpenEncryptedStore", NAPI_AUTO_LENGTH, &name);
    napi_create_async_work(env, NULL, name, Execute, Complete, task, &task->work);
    napi_queue_async_work(env, task->work);
    return promise;
}

static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"openEncryptedStore", NULL, OpenEncryptedStore, NULL, NULL, NULL, napi_default, NULL},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = NULL,
    .nm_register_func = Init,
    .nm_modname = "hm_sdk_diag",
    .nm_priv = NULL,
    .reserved = {0},
};

extern void hm_sdk_diag_register(void) __attribute__((constructor));
void hm_sdk_diag_register(void)
{
    napi_module_register(&g_module);
}
