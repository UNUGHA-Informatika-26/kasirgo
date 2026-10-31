package com.example.kasirgo

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bluetoothResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLUETOOTH_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "requestBluetoothAccessAndEnable") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (bluetoothResult != null) {
                result.error("busy", "Permintaan Bluetooth sedang berlangsung.", null)
                return@setMethodCallHandler
            }

            bluetoothResult = result
            requestBluetoothPermissions()
        }
    }

    private fun requestBluetoothPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        } else {
            emptyArray()
        }
        val missingPermissions = permissions.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            requestPermissions(
                missingPermissions.toTypedArray(),
                REQUEST_BLUETOOTH_PERMISSIONS,
            )
            return
        }

        enableBluetoothIfNeeded()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_BLUETOOTH_PERMISSIONS) return

        if (
            grantResults.isEmpty() ||
            grantResults.any { it != PackageManager.PERMISSION_GRANTED }
        ) {
            completeBluetoothRequest("permissionDenied")
            return
        }

        enableBluetoothIfNeeded()
    }

    private fun enableBluetoothIfNeeded() {
        val adapter =
            (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        if (adapter == null) {
            completeBluetoothRequest("bluetoothDisabled")
            return
        }

        if (adapter.isEnabled) {
            completeBluetoothRequest("enabled")
            return
        }

        try {
            startActivityForResult(
                Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE),
                REQUEST_ENABLE_BLUETOOTH,
            )
        } catch (error: SecurityException) {
            bluetoothResult?.error("bluetooth_permission", error.message, null)
            bluetoothResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_ENABLE_BLUETOOTH) return

        completeBluetoothRequest(
            if (resultCode == Activity.RESULT_OK) "enabled" else "bluetoothDisabled",
        )
    }

    private fun completeBluetoothRequest(status: String) {
        bluetoothResult?.success(status)
        bluetoothResult = null
    }

    private companion object {
        const val BLUETOOTH_CHANNEL = "kasirgo/bluetooth"
        const val REQUEST_BLUETOOTH_PERMISSIONS = 9171
        const val REQUEST_ENABLE_BLUETOOTH = 9172
    }
}
