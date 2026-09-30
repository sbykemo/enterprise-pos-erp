#!/bin/bash
# تشغيل الاختبارات أولاً
npm test || exit 1

# مزامنة ورفع التغييرات
git add .
git commit -m "Auto-ship update"
git push origin main