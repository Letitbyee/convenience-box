package com.cc.conveniencebox;

import android.annotation.SuppressLint;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;

public class MainActivity extends android.app.Activity {

    private WebView web;
    private int depth = 0;   // 0 = 在主页（可以退出）；>0 = 还有层可以退

    /** 页面通过这个桥把「还有几层可退」告诉安卓壳 */
    public class Host {
        @JavascriptInterface
        public void setDepth(int d) { depth = d; }
        @JavascriptInterface
        public int getDepth() { return depth; }
    }

    private final android.window.OnBackInvokedCallback backCb =
        new android.window.OnBackInvokedCallback() {
            @Override public void onBackInvoked() { handleBack(); }
        };

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Window w = getWindow();
        w.setStatusBarColor(Color.parseColor("#EEF2FB"));
        w.setNavigationBarColor(Color.parseColor("#EEF2FB"));
        View decor = w.getDecorView();
        decor.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        w.setNavigationBarDividerColor(Color.parseColor("#D7DEEC"));

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setAllowUniversalAccessFromFileURLs(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setLoadWithOverviewMode(true);
        s.setUseWideViewPort(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        web.addJavascriptInterface(new Host(), "CcHost");
        web.setBackgroundColor(Color.parseColor("#EEF2FB"));
        web.loadUrl("file:///android_asset/index.html");
        setContentView(web);

        // 安卓 13+：走新的返回分发器（老 onBackPressed 在部分机型上收不到）
        if (Build.VERSION.SDK_INT >= 33) {
            try {
                getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, backCb);
            } catch (Throwable t) { /* 失败也没关系，下面还有 onBackPressed */ }
        }
    }

    private void handleBack() {
        if (depth > 0) {
            if (web != null) web.evaluateJavascript("window.__gbBack && window.__gbBack();", null);
        } else {
            finish();
        }
    }

    @Override
    public void onBackPressed() {
        handleBack();
    }
}
