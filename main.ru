import os
from telegram import Update
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
from telegram import InlineKeyboardButton, InlineKeyboardMarkup
from telegram.constants import ParseMode
from data import MENU
import logging

# Включите логирование
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TOKEN = os.environ['TOKEN']
user_history = {}

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
        logger.error(f"Ошибка отправки: {e}")
        await message.reply_text(
            text=menu.get("text", "Ошибка загрузки"),
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

def main():
    application = Application.builder().token(TOKEN).build()
    
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CallbackQueryHandler(button_click))
    
    logger.info("Бот запущен! Ожидаем сообщения...")
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
