from flask import Flask
import requests
import time
import random

app = Flask(__name__)

@app.route("/")
def home():

    time.sleep(random.uniform(0.1, 0.3))

    r = requests.get(
        "http://worker.istio-demo.svc.cluster.local"
    )

    return f"API V1 → {r.text}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)