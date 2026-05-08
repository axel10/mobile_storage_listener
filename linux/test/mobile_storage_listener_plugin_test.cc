#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "include/mobile_storage_listener/mobile_storage_listener_plugin.h"
#include "mobile_storage_listener_plugin_private.h"

// This demonstrates a simple unit test of the C portion of this plugin's
// implementation.
//
// Once you have built the plugin's example app, you can run these tests
// from the command line. For instance, for a plugin called my_plugin
// built for x64 debug, run:
// $ build/linux/x64/debug/plugins/my_plugin/my_plugin_test

namespace mobile_storage_listener {
namespace test {

TEST(MobileStorageListenerPlugin, GetPlatformVersion) {
  g_autoptr(FlMethodResponse) response = get_platform_version();
  ASSERT_NE(response, nullptr);
  ASSERT_TRUE(FL_IS_METHOD_SUCCESS_RESPONSE(response));
  FlValue* result = fl_method_success_response_get_result(
      FL_METHOD_SUCCESS_RESPONSE(response));
  ASSERT_EQ(fl_value_get_type(result), FL_VALUE_TYPE_STRING);
  // The full string varies, so just validate that it has the right format.
  EXPECT_THAT(fl_value_get_string(result), testing::StartsWith("Linux "));
}

TEST(MobileStorageListenerPlugin, CreateStorageEvent) {
  g_autoptr(FlValue) event = create_storage_event("mounted", "/media/usb");

  ASSERT_NE(event, nullptr);
  ASSERT_EQ(fl_value_get_type(event), FL_VALUE_TYPE_MAP);

  FlValue* type = fl_value_lookup_string(event, "type");
  ASSERT_NE(type, nullptr);
  ASSERT_EQ(fl_value_get_type(type), FL_VALUE_TYPE_STRING);
  EXPECT_STREQ(fl_value_get_string(type), "mounted");

  FlValue* path = fl_value_lookup_string(event, "path");
  ASSERT_NE(path, nullptr);
  ASSERT_EQ(fl_value_get_type(path), FL_VALUE_TYPE_STRING);
  EXPECT_STREQ(fl_value_get_string(path), "/media/usb");
}

}  // namespace test
}  // namespace mobile_storage_listener
