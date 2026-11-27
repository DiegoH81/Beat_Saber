import json
import socket
import time

from pykinect2 import PyKinectRuntime, PyKinectV2

UDP_IP = "127.0.0.1"
UDP_PORT = 49152
PLAYER_REACQUIRE_SECONDS = 1.0

LANDMARK_TO_KINECT_JOINT = {
    0: PyKinectV2.JointType_HandLeft,
    1: PyKinectV2.JointType_HandRight,
    2: PyKinectV2.JointType_WristLeft,
    3: PyKinectV2.JointType_WristRight,
    4: PyKinectV2.JointType_ElbowLeft,
    5: PyKinectV2.JointType_ElbowRight,
    6: PyKinectV2.JointType_ShoulderLeft,
    7: PyKinectV2.JointType_ShoulderRight,
    8: PyKinectV2.JointType_Head
}


def get_tracking_data(body):
    if body is None:
        return {"body_tracked": False, "landmarks": {}}

    landmarks = {}
    for landmark_index, joint_type in LANDMARK_TO_KINECT_JOINT.items():
        joint = body.joints[joint_type]
        if joint.TrackingState == PyKinectV2.TrackingState_NotTracked:
            continue

        visibility = 1.0 if joint.TrackingState == PyKinectV2.TrackingState_Tracked else 0.5
        landmarks[str(landmark_index)] = [
            joint.Position.x,
            joint.Position.y,
            joint.Position.z,
            visibility,
        ]

    return {
        "body_tracked": True,
        "clipped_edges": body.clipped_edges,
        "landmarks": landmarks,
    }


def main():
    kinect = PyKinectRuntime.PyKinectRuntime(PyKinectV2.FrameSourceTypes_Body)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    print(f"Starting tracking... sending UDP data to {UDP_IP}:{UDP_PORT}")
    print("Ctrl+C to stop.\n")

    player_id = None
    last_seen = 0.0
    try:
        while True:
            if kinect.has_new_body_frame():
                frame = kinect.get_last_body_frame()
                if frame is not None:
                    now = time.monotonic()
                    tracked = [body for body in frame.bodies if body.is_tracked]
                    player = next((body for body in tracked if body.tracking_id == player_id), None)
                    if player is None and tracked and (
                        player_id is None or now - last_seen >= PLAYER_REACQUIRE_SECONDS
                    ):
                        player = tracked[0]
                    if player is not None:
                        player_id = player.tracking_id
                        last_seen = now

                    payload = get_tracking_data(player)
                    sock.sendto(json.dumps(payload).encode("utf-8"), (UDP_IP, UDP_PORT))

            time.sleep(0.001)

    except KeyboardInterrupt:
        print("\nStopping tracking...")
    finally:
        sock.close()
        kinect.close()


if __name__ == "__main__":
    main()
