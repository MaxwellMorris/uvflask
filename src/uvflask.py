from flask import Flask
import numpy as np


app = Flask(__name__)

@app.route("/")
def hello_world():
    NP = np
    x = np.array([2, 3, 5]) + np.array([2, 3, 5])
    return f"<p>Hello, World! Numpy: {NP}, x = {x} </p>"

def main():
    app.run(host="0.0.0.0", port=5000)

if __name__ == '__main__':
    main()
