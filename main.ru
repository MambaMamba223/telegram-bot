import os
from telegram import Update
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.constants import ParseMode
from data import MENU
from flask import Flask, request
from threading import Thread
import requests
import time

TOKEN = os.environ['TOKEN']
user_history = {}

# Flask приложение
app = Flask(__name__)

# Единый URL для всех запросов (возьмите из вкладки "Web" в Replit)
REPLIT_URL = "https://TelegramBOT--sasharikkert9.repl.co"  # ← ЗАМЕНИТЕ НА СВОЙ!

@app.route('/')
def home():
    return "Бот активен! Сервер работает нормально"

@app.route('/ping')
def ping():
    return "pong", 200

def run_flask():
    try:
        app.run(host='0.0.0.0', port=3000)
    except OSError:
        app.run(host='0.0.0.0', port=3001)  # Альтернативный порт

def self_ping():
    while True:
        try:
            requests.get(f"{REPLIT_URL}/ping", timeout=5)
        except Exception as e:
            print(f"Ошибка ping: {str(e)[:100]}...")
        time.sleep(240)

def escape_html(text):
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    user_history[chat_id] = ["start"]
    await show_menu(update.message, "start")

async def button_click(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    chat_id = update.effective_chat.id
    button_data = query.data

    if button_data == "Назад":
        if len(user_history[chat_id]) > 1:
            user_history[chat_id].pop()
            previous_menu = user_history[chat_id][-1]
            await show_menu(query.message, previous_menu)
        else:
            await show_menu(query.message, "start")
    else:
        user_history[chat_id].append(button_data)
        await show_menu(query.message, button_data)

async def show_menu(message, menu_name):
    menu = MENU.get(menu_name, {
        "text": "🚧 Раздел в разработке",
        "buttons": [["Назад"]]
    })

    parse_mode = ParseMode.HTML if menu.get("parse_mode") == "HTML" else None
    text = menu.get("text", "")

    if parse_mode != ParseMode.HTML:
        text = escape_html(text)

    keyboard = [
        [InlineKeyboardButton(btn, callback_data=btn) for btn in row]
        for row in menu.get("buttons", [])
    ]

    try:
        if menu.get("image"):
            await message.reply_photo(
                photo=menu["image"],
                caption=text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode=parse_mode
            )
        else:
            await message.reply_text(
                text=text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode=parse_mode
            )
    except Exception as e:
        print(f"Ошибка отправки: {e}")
        await message.reply_text(
            text=menu.get("text", "Ошибка загрузки"),
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

async def post_init(application: Application):
    print(f"✅ Бот запущен! Мониторьте URL: {REPLIT_URL}")
    print(f"👉 Тестовый URL: {REPLIT_URL}/ping")

def main():
    # Запуск Flask в отдельном потоке
    Thread(target=run_flask, daemon=True).start()

    # Запуск self-ping
    Thread(target=self_ping, daemon=True).start()

    # Инициализация бота
    application = Application.builder().token(TOKEN).post_init(post_init).build()

    # Обработчики
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button_click))

    # Запуск с обработкой конфликтов
    application.run_polling(
        allowed_updates=Update.ALL_TYPES,
        drop_pending_updates=True
    )

if __name__ == "__main__":
    main()
