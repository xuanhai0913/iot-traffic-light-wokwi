#!/usr/bin/env python3
"""Tiny MQTT subscriber for verifying the C# backend publishes commands.

Usage:
    python3 scripts/mqtt-sniff.py [--topic traffic/.../commands] [--seconds 12]

Connects to broker.hivemq.com:1883 and prints every payload received on the
given topic. Exits after the timeout.
"""
import argparse
import json
import sys
import time

import paho.mqtt.client as mqtt

DEFAULT_TOPIC = "traffic/hainx-iot-traffic-light/intersections/1/commands"
DEFAULT_BROKER = "broker.hivemq.com"
DEFAULT_PORT = 1883
DEFAULT_SECONDS = 12

received = []


def on_connect(client, userdata, flags, rc):
    if rc != 0:
        print(f"connect failed: rc={rc}", file=sys.stderr)
        sys.exit(1)
    print(f"connected to {userdata['broker']}:{userdata['port']}")
    client.subscribe(userdata["topic"], qos=1)


def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8", errors="replace")
    received.append((msg.topic, payload))
    print(f"--- {time.strftime('%H:%M:%S')} {msg.topic}")
    try:
        parsed = json.loads(payload)
        print(json.dumps(parsed, indent=2, ensure_ascii=False))
    except ValueError:
        print(payload)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--topic", default=DEFAULT_TOPIC)
    parser.add_argument("--broker", default=DEFAULT_BROKER)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--seconds", type=int, default=DEFAULT_SECONDS)
    args = parser.parse_args()

    userdata = {
        "topic": args.topic,
        "broker": args.broker,
        "port": args.port,
    }
    client = mqtt.Client(
        client_id="iot-sniff-" + str(int(time.time())),
        userdata=userdata,
    )
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"connecting to {args.broker}:{args.port} ...")
    print(f"will listen for up to {args.seconds}s on topic '{args.topic}'", flush=True)
    deadline = time.monotonic() + args.seconds

    def maybe_exit(client_, userdata_):
        if time.monotonic() >= deadline and not received:
            client_.disconnect()

    client.connect(args.broker, args.port, 60)
    client.loop_start()
    try:
        while time.monotonic() < deadline:
            time.sleep(0.5)
    finally:
        client.loop_stop()
        client.disconnect()

    print(f"=== received {len(received)} message(s) ===")
    return 0 if received else 2


if __name__ == "__main__":
    sys.exit(main())
