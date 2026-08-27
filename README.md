# input-toggled

สลับภาษา ไทย/EN ด้วย `cmd+space` แบบ**ทันที** (~5ms) — แก้ปัญหา macOS สลับภาษาช้า/ต้องกดสองรอบหลังไม่ได้ใช้เครื่องนาน

## มันแก้อะไร

ตัวสลับภาษาของ macOS (`TextInputSwitcher`) เป็น process ที่ระบบปิดทิ้งตอนไม่ใช้
พอกดสลับครั้งแรกหลังพักเครื่อง ระบบต้องปลุกมันขึ้นมาใหม่ ยิ่งเครื่อง swap หนักยิ่งช้า
บางทีกดรอบแรกหายไปเลย ต้องกดซ้ำ แล้วภาษาก็เด้งไปเด้งมา

ตัวนี้เป็น daemon เล็ก ๆ (Swift ~100 บรรทัด, ไม่มี dependency) ที่:

- ดักปุ่ม `cmd+space` เองผ่าน CGEventTap
- สลับ Thai ↔ U.S. ตรงผ่าน API ของระบบ ไม่ผ่านตัวที่ช้า
- อยู่ประจำตลอด (LaunchAgent) — reboot มาก็กลับมาเอง

## ต้องมี

- Mac (Apple Silicon หรือ Intel ก็ได้ — compile บนเครื่องตัวเอง)
- Xcode Command Line Tools (`xcode-select --install`)
- Input source ในเครื่องเป็น **Thai + U.S.** (ถ้าใช้ layout อื่น แก้ 2 บรรทัดบนสุดของ `hotkeyd.swift` — ค่า `thaiID` / `usID`)

## ติดตั้ง

```bash
bash install.sh
```

จบแล้วเหลือ 1 step ที่ macOS บังคับให้กดเอง: หน้า System Settings จะเปิดขึ้นมา —
**ลากไฟล์ `input-toggled` จากหน้าต่าง Finder ใส่ลิสต์ Accessibility แล้วเปิดสวิตช์**
รอ 3 วิ แล้วกด `cmd+space` ได้เลย

เช็คสถานะ: `tail ~/.local/share/input-toggled.log` — ต้องขึ้น `event tap active`

## ข้อควรรู้

- **ใครใช้ `cmd+space` เปิด Spotlight อยู่** — ปุ่มจะถูกยึดไปสลับภาษาแทน
  ย้าย Spotlight ไปปุ่มอื่นก่อน (System Settings → Keyboard → Keyboard Shortcuts → Spotlight)
- ช่อง password (secure input) จะกดไม่ติด — เป็นข้อจำกัดของ event tap ทุกตัวบน macOS
- ถ้าแก้ code แล้ว compile ใหม่ ต้องลากใส่ Accessibility ใหม่ (macOS ผูกสิทธิ์กับ hash ของไฟล์)

## ถอนการติดตั้ง

```bash
bash uninstall.sh
```
