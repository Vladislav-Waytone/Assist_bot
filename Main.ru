import telebot
import requests
import os
import threading
import time
from datetime import datetime

BOT_TOKEN = os.getenv("BOT_TOKEN")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
bot = telebot.TeleBot(BOT_TOKEN)

reminders = {}

# --- Функция запроса к Groq ---
def ask_groq(prompt):
    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }
    data = {
        "model": "llama3-70b-8192",
        "messages": [
            {"role": "system", "content": "Ты позитивный, умный, чуткий ассистент на русском языке. Помогаешь с планами, мотивацией и временем."},
            {"role": "user", "content": prompt}
        ]
    }
    response = requests.post("https://api.groq.com/openai/v1/chat/completions", headers=headers, json=data)
    result = response.json()
    return result["choices"][0]["message"]["content"] if "choices" in result else "Ошибка ответа от ИИ"

# --- Команда старта ---
@bot.message_handler(commands=['start'])
def start(message):
    bot.send_message(message.chat.id, "Привет! Я твой ассистент. Напиши мне план на день или задай вопрос.")

# --- Команда установки напоминания ---
@bot.message_handler(commands=['напомни'])
def remind_command(message):
    try:
        text = message.text.replace("/напомни", "").strip()
        parts = text.split(" в ")
        if len(parts) != 2:
            bot.reply_to(message, "Формат: /напомни Сделать звонок в 14:30")
            return
        note, time_str = parts
        remind_time = datetime.strptime(time_str, "%H:%M").time()
        reminders[message.chat.id] = {"text": note, "time": remind_time}
        bot.reply_to(message, f"Напоминание установлено: '{note}' в {remind_time}")
    except Exception as e:
        bot.reply_to(message, "Ошибка: используйте формат /напомни [текст] в ЧЧ:ММ")

# --- Обработка обычных сообщений ---
@bot.message_handler(func=lambda message: True)
def chat(message):
    reply = ask_groq(message.text)
    bot.send_message(message.chat.id, reply)

# --- Фоновый поток для напоминаний ---
def reminder_loop():
    while True:
        now = datetime.now().time()
        for chat_id, data in list(reminders.items()):
            if data["time"].hour == now.hour and data["time"].minute == now.minute:
                bot.send_message(chat_id, f"🔔 Напоминание: {data['text']}")
                del reminders[chat_id]
        time.sleep(60)

threading.Thread(target=reminder_loop, daemon=True).start()

# --- Запуск бота ---
bot.polling(none_stop=True)
