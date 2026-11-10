package io.tomiesu.manager.ui

/**
 * 隐身入口的常开落点：`tsud stealth` 守卫 am start 到这里。
 *
 * 为什么需要它：藏图标要停用的是 launcher 组件，而已停用的组件无法被 am start ——
 * 守卫若指向 launcher 组件，图标一藏入口就死。这个 Activity 不带 LAUNCHER filter、
 * 永不停用，直接继承 MainActivity，行为与从图标打开一致。
 */
class StealthLaunchActivity : MainActivity()
