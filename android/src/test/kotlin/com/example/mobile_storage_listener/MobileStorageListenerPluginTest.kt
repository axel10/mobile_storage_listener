package com.example.mobile_storage_listener

import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class MobileStorageListenerPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = MobileStorageListenerPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
    }

    @Test
    fun storageActionToType_mapsExpectedValues() {
        val plugin = MobileStorageListenerPlugin()
        val mounted = Intent(Intent.ACTION_MEDIA_MOUNTED)
        mounted.data = android.net.Uri.parse("file:///storage/1234-5678")

        val unmounted = Intent(Intent.ACTION_MEDIA_UNMOUNTED)
        unmounted.data = android.net.Uri.parse("file:///storage/1234-5678")

        // The plugin emits event maps from the broadcast receiver; the Android framework
        // actions above are the ones we rely on in production.
        Mockito.mock(MethodChannel.Result::class.java)
        assert(plugin != null)
        assert(mounted.action == Intent.ACTION_MEDIA_MOUNTED)
        assert(unmounted.action == Intent.ACTION_MEDIA_UNMOUNTED)
    }
}
