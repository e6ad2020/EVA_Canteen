#!/bin/bash

# 🛠️ إعدادات المشروع
REPO_PATH="/home/eyad/EVA_Canteen"  # مسار المستودع
BRANCH="main"                       # اسم الفرع الرئيسي

# 🧭 الانتقال إلى مجلد المشروع
cd "$REPO_PATH" || { echo "❌ فشل الدخول إلى المجلد $REPO_PATH"; exit 1; }

# ✅ التأكد من وجود تغييرات غير مرفوعة
if [[ -n $(git status --porcelain) ]]; then
    echo "📂 تم اكتشاف تغييرات جديدة، جاري رفعها..."

    # ➕ إضافة كل الملفات
    git add .

    # 📝 إنشاء Commit جديد بتاريخ ووقت
    git commit -m "Auto commit: $(date +'%Y-%m-%d %H:%M:%S')"

    # 🔐 التأكد من SSH Agent شغال
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519
    fi

    # 🚀 رفع التغييرات إلى الفرع الرئيسي
    git push origin "$BRANCH"

    echo "✅ تم رفع التغييرات بنجاح!"
else
    echo "✅ لا توجد تغييرات لرفعها."
fi

