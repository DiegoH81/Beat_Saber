import json
import socket
import time

from pykinect2 import PyKinectV2
from pykinect2.PyKinectV2 import *
from pykinect2 import PyKinectRuntime

UDP_IP = "127.0.0.1"
UDP_PORT = 5555

LANDMARK_TO_KINECT_JOINT = {
    0: PyKinectV2.JointType_HandLeft,
    1: PyKinectV2.JointType_HandRight,
    2: PyKinectV2.JointType_WristLeft,
    3: PyKinectV2.JointType_WristRight,
    4: PyKinectV2.JointType_ElbowLeft,
    5: PyKinectV2.JointType_ElbowRight,
    6: PyKinectV2.JointType_ShoulderLeft,
    7: PyKinectV2.JointType_ShoulderRight,
}


def get_tracking_data(kinect):
    results = []

    if not kinect.has_new_body_frame():
        return results

    bodies = kinect.get_last_body_frame()
    if bodies is None:
        return results

    for i in range(kinect.max_body_count):
        body = bodies.bodies[i]
        if not body.is_tracked:
            continue

        joints = body.joints
        landmarks = {}

        for landmark_index, joint_type in LANDMARK_TO_KINECT_JOINT.items():
            joint = joints[joint_type]

            if joint.TrackingState == PyKinectV2.TrackingState_NotTracked:
                continue

            visibility = 1.0 if joint.TrackingState == PyKinectV2.TrackingState_Tracked else 0.5

            landmarks[str(landmark_index)] = [
                joint.Position.x,
                joint.Position.y,
                joint.Position.z,
                visibility,
            ]

        if landmarks:
            results.append({"body_index": i, "landmarks": landmarks})

    return results


def main():
    kinect = PyKinectRuntime.PyKinectRuntime(PyKinectV2.FrameSourceTypes_Body)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    print(f"Starting tracking... sending UDP data to {UDP_IP}:{UDP_PORT}")
    print("Ctrl+C to stop.\n")

    try:
        while True:
            bodies = get_tracking_data(kinect)

            for body in bodies:
                payload = {"landmarks": body["landmarks"]}
                message = json.dumps(payload).encode("utf-8")
                sock.sendto(message, (UDP_IP, UDP_PORT))

            if bodies:
                print(f"Sent frame with {len(bodies)} body(ies) tracked")

            time.sleep(0.001)

    except KeyboardInterrupt:
        print("\nStopping tracking...")
    finally:
        sock.close()
        kinect.close()


if __name__ == "__main__":
    main()