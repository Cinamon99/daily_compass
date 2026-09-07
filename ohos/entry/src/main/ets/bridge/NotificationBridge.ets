// 每日罗盘 · 鸿蒙原生通知桥接
// 由 Flutter 侧 MethodChannel('compass/notifications') 调用。
//
// ⚠️ 以下 API 基于 HarmonyOS NEXT (API 12) + @kit.NotificationKit。
// 具体枚举名 / 字段名请以你本机 Flutter-OHOS SDK 版本为准（无法在
// 没有 DevEco/SDK 的环境编译验证，仅作移植蓝本）。

import { reminderAgent } from '@kit.NotificationKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 我们的提醒 id -> 系统 reminderAgent 返回的系统级 id
const idMap: Map<number, number> = new Map();

// PUBLISH_AGENT_REMINDER 为系统权限，已在 module.json5 声明；
// 鸿蒙会在首次 publishReminder 时向用户弹授权。这里默认 true。
export async function requestPermission(): Promise<boolean> {
  return true;
}

export async function schedule(params: Record<string, Object>): Promise<void> {
  const ourId: number = params['id'] as number;
  const triggerMs: number = params['triggerMs'] as number;
  const title: string = params['title'] as string;
  const body: string = params['body'] as string;
  const fullScreen: boolean = (params['fullScreen'] as boolean) ?? true;

  if (fullScreen) {
    // 系统级提醒：关 App 也能准时响，像真闹钟
    const req: reminderAgent.ReminderRequestCalendar = {
      reminderType: reminderAgent.ReminderType.REMINDER_TYPE_CALENDAR,
      triggerTime: triggerMs,
      title: title,
      content: body,
      expiredTime: triggerMs + 30 * 60 * 1000, // 触发后 30 分钟内有效
      ringDuration: 60 * 1000, // 持续响 60 秒，模拟闹钟
      snoozeTimes: 0,
      timeZone: ''
    };
    try {
      const sysId: number = await reminderAgent.publishReminder(req);
      idMap.set(ourId, sysId);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`publishReminder failed code=${e.code} msg=${e.message}`);
    }
  } else {
    // 普通即时通知
    const req: notificationManager.NotificationRequest = {
      id: ourId,
      content: {
        contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: body
        }
      }
    };
    try {
      await notificationManager.publishNotification(req);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`publishNotification failed code=${e.code} msg=${e.message}`);
    }
  }
}

export async function cancel(ourId: number): Promise<void> {
  const sysId = idMap.get(ourId);
  if (sysId !== undefined) {
    try {
      await reminderAgent.cancelReminder(sysId);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`cancelReminder failed code=${e.code} msg=${e.message}`);
    }
    idMap.delete(ourId);
  }
}

export async function cancelAll(): Promise<void> {
  idMap.forEach(async (sysId: number) => {
    try {
      await reminderAgent.cancelReminder(sysId);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`cancelReminder failed code=${e.code} msg=${e.message}`);
    }
  });
  idMap.clear();
}

export async function showTest(params: Record<string, Object>): Promise<void> {
  const req: notificationManager.NotificationRequest = {
    id: 999,
    content: {
      contentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: {
        title: params['title'] as string,
        text: params['body'] as string
      }
    }
  };
  try {
    await notificationManager.publishNotification(req);
  } catch (err) {
    const e = err as BusinessError;
    console.error(`publishNotification failed code=${e.code} msg=${e.message}`);
  }
}
