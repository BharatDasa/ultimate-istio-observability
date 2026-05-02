from flask import Flask
import time, random

app = Flask(__name__)

@app.route("/")
def work():
    time.sleep(random.uniform(0.1, 0.2))
    return "Worker OK"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
