.class public LCh;
.super Ljava/lang/Object;

# 用法: app_process /system/bin Ch <pkg> <uid> <channelId> <channelName>
# 作用: 把指定 app 的某条 notification channel 置为 BLOCKED(importance=0)
#       等价于用户在「设置→通知→应用→渠道」里手动关闭

.method public static main([Ljava/lang/String;)V
    .locals 1
    invoke-static {}, Landroid/os/Looper;->prepareMainLooper()V
    :try_start
    invoke-static {p0}, LCh;->run([Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch
    return-void
    :catch
    move-exception v0
    invoke-static {v0}, LCh;->err(Ljava/lang/Throwable;)V
    return-void
.end method

.method static run([Ljava/lang/String;)V
    .locals 9
    invoke-static {}, LCh;->getCtx()Landroid/content/Context;
    move-result-object v0
    if-nez v0, :ctxok
    const-string v7, "NO_CONTEXT"
    invoke-static {v7}, LCh;->log(Ljava/lang/String;)V
    return-void
    :ctxok

    const-string v7, "notification"
    invoke-virtual {v0, v7}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v1
    check-cast v1, Landroid/app/NotificationManager;

    const/4 v8, 0x0
    aget-object v2, p0, v8            # pkg
    const/4 v8, 0x1
    aget-object v3, p0, v8            # uid str
    invoke-static {v3}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v3                     # uid int
    const/4 v8, 0x2
    aget-object v4, p0, v8            # importance str
    invoke-static {v4}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v8                     # importance int
    const/4 v7, 0x3
    aget-object v4, p0, v7             # channelId
    const/4 v7, 0x4
    aget-object v5, p0, v7             # channelName

    new-instance v6, Landroid/app/NotificationChannel;
    invoke-direct {v6, v4, v5, v8}, Landroid/app/NotificationChannel;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;I)V

    invoke-virtual {v1, v2, v3, v6}, Landroid/app/NotificationManager;->updateNotificationChannel(Ljava/lang/String;ILandroid/app/NotificationChannel;)V

    const-string v7, "OK"
    invoke-static {v7}, LCh;->log(Ljava/lang/String;)V
    return-void
.end method

.method static getCtx()Landroid/content/Context;
    .locals 2
    :ts
    invoke-static {}, Landroid/app/ActivityThread;->systemMain()Landroid/app/ActivityThread;
    move-result-object v0
    invoke-static {}, Landroid/app/ActivityThread;->currentSystemContext()Landroid/content/Context;
    move-result-object v1
    :te
    .catch Ljava/lang/Throwable; {:ts .. :te} :cx
    if-eqz v1, :nul
    return-object v1

    :cx
    move-exception v0
    invoke-static {v0}, LCh;->err(Ljava/lang/Throwable;)V
    :nul
    const/4 v0, 0x0
    return-object v0
.end method

.method static log(Ljava/lang/String;)V
    .locals 2
    sget-object v0, Ljava/lang/System;->out:Ljava/io/PrintStream;
    invoke-virtual {v0, p0}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    return-void
.end method

.method static err(Ljava/lang/Throwable;)V
    .locals 2
    sget-object v0, Ljava/lang/System;->out:Ljava/io/PrintStream;
    invoke-virtual {p0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    return-void
.end method
