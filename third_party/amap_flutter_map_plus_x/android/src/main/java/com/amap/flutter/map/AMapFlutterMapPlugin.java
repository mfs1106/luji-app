package com.amap.flutter.map;

import android.app.Activity;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import com.amap.flutter.map.utils.LogUtil;


import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

/**
 * AmapFlutterMapPlugin
 */
public class AMapFlutterMapPlugin implements
        FlutterPlugin,
        ActivityAware {
    private static final String CLASS_NAME = "AMapFlutterMapPlugin";
    private FlutterPluginBinding pluginBinding;
    private Lifecycle lifecycle;

    private static final String VIEW_TYPE = "com.amap.flutter.map";

    // v1 embedding (registerWith) removed for Flutter 3.32+. Use v2 embedding via FlutterPlugin.

    public AMapFlutterMapPlugin() {
    }

    // FlutterPlugin

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        LogUtil.i(CLASS_NAME, "onAttachedToEngine==>");
        pluginBinding = binding;
        binding
                .getPlatformViewRegistry()
                .registerViewFactory(
                        VIEW_TYPE,
                        new AMapPlatformViewFactory(
                                binding.getBinaryMessenger(),
                                new LifecycleProvider() {
                                    @Nullable
                                    @Override
                                    public Lifecycle getLifecycle() {
                                        return lifecycle;
                                    }
                                }));
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        LogUtil.i(CLASS_NAME, "onDetachedFromEngine==>");
        pluginBinding = null;
    }


    // ActivityAware

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        LogUtil.i(CLASS_NAME, "onAttachedToActivity==>");
        // 与 FlutterLifecycleAdapter.getActivityLifecycle(binding) 等价：
        // 直接取 Activity 的 Lifecycle（FlutterActivity 继承自 ComponentActivity，
        // 本身即 LifecycleOwner）。原 API 在部分 embedding 注入环境下不可用，
        // 此处改用等价实现，行为不变。
        Activity activity = binding.getActivity();
        if (activity instanceof LifecycleOwner) {
            lifecycle = ((LifecycleOwner) activity).getLifecycle();
        }
    }

    @Override
    public void onDetachedFromActivity() {
        LogUtil.i(CLASS_NAME, "onDetachedFromActivity==>");
        lifecycle = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        LogUtil.i(CLASS_NAME, "onReattachedToActivityForConfigChanges==>");
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        LogUtil.i(CLASS_NAME, "onDetachedFromActivityForConfigChanges==>");
        this.onDetachedFromActivity();
    }
}