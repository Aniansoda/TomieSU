package io.tomiesu.manager.ui.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import top.yukonga.miuix.kmp.blur.LayerBackdrop

/**
 * XEK 设计 token 的最小适配层。
 *
 * 隐藏环境页面（hidepack）原本基于 XEK 自家的 Xc 设计系统；这里只保留页面真正
 * 引用到的三样东西——颜色三元组、圆角表、玻璃背景修饰符——其余一律走本工程的
 * Miuix / Material3 主题，避免把整套 XcTheme（约 800 行且与 XEK 主题绑定）搬进来。
 */

@Immutable
data class XcColorsShim(
    val surface: Color,
    val text: Color,
    val textSecondary: Color,
)

@Immutable
data class XcShapesShim(
    val xs: Shape = RoundedCornerShape(XcRadius.xs),
    val sm: Shape = RoundedCornerShape(XcRadius.sm),
    val md: Shape = RoundedCornerShape(XcRadius.md),
    val lg: Shape = RoundedCornerShape(XcRadius.lg),
    val xl: Shape = RoundedCornerShape(XcRadius.xl),
)

object Xc {
    val colors: XcColorsShim
        @Composable @ReadOnlyComposable
        get() {
            val scheme = MaterialTheme.colorScheme
            return XcColorsShim(
                surface = scheme.surfaceContainerHigh,
                text = scheme.onSurface,
                textSecondary = scheme.onSurfaceVariant,
            )
        }

    val shapes: XcShapesShim
        @Composable @ReadOnlyComposable
        get() = XcShapesShim()
}

object XcRadius {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 20.dp
    val bar = 12.dp
}

/**
 * 玻璃容器背景。XEK 版本做折射/内高光；这里退化为「底色 + 1px 描边」，
 * 视觉更朴素但不需要离屏采样，也不会在没有 blur 的纯 Miuix 页面上闪。
 */
@Composable
fun Modifier.xGlassBody(
    backdrop: LayerBackdrop? = null,
    shape: Shape = RoundedCornerShape(XcRadius.md),
    tint: Color = Color.Unspecified,
    blurRadius: Dp = 2.dp,
    refraction: Dp = 34.dp,
    rimColor: Color = Color.Unspecified,
    rim: Boolean = true,
    innerHighlight: Boolean = true,
): Modifier {
    val fill = if (tint == Color.Unspecified) MaterialTheme.colorScheme.surfaceContainerHigh else tint
    val stroke = if (rimColor == Color.Unspecified) MaterialTheme.colorScheme.outlineVariant else rimColor
    var m = this.background(fill, shape)
    if (rim) m = m.border(1.dp, stroke, shape)
    return m
}

/** 根层对话框宿主在本工程不存在，直接用 Compose Dialog 顶上。 */
@Composable
fun XDialog(
    show: Boolean,
    onDismissRequest: () -> Unit,
    maxWidth: Dp = 420.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    if (!show) return
    Dialog(onDismissRequest = onDismissRequest) {
        Surface(
            shape = RoundedCornerShape(XcRadius.xl),
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
        ) {
            Column(modifier = Modifier.padding(20.dp).widthIn(max = maxWidth)) {
                content()
            }
        }
    }
}
