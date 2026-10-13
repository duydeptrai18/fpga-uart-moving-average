import serial
from collections import deque
queue = deque([0,0,0,0],maxlen=4)

def uart_send_check(uart, queue, new_number):
    uart.write(bytes([new_number]))
    received = uart.read(1)

    queue.append(new_number)
    sim_result = sum(queue) //4
    
    if not received:
        print("ERROR! No response")
        return
    if(sim_result != received[0]):
        print(f"ERROR! sim_result: {sim_result}, received: {received[0]}")
    else:
        print(f"PASSED! sim_result: {sim_result}, received: {received[0]}")
    
    
with serial.Serial("COM5", baudrate=115200, timeout=2) as uart:
    uart.reset_input_buffer()
    
    #1. Long sequence: send one sample and wait for its result before sending the next
    # print("Test 1 begins:")
    # uart_send_check(uart, queue, 4)
    # uart_send_check(uart, queue, 8)
    # uart_send_check(uart, queue, 12)
    # uart_send_check(uart, queue, 16)
    # uart_send_check(uart, queue, 20)
    # uart_send_check(uart, queue, 0)
    # uart_send_check(uart, queue, 255)
    # uart_send_check(uart, queue, 255)
    # uart_send_check(uart, queue, 255)
    # uart_send_check(uart, queue, 255)
    # uart_send_check(uart, queue, 0)
    # uart_send_check(uart, queue, 0)
    # uart_send_check(uart, queue, 0)
    # uart_send_check(uart, queue, 0)
    # uart_send_check(uart, queue, 1)
    # uart_send_check(uart, queue, 2)
    # uart_send_check(uart, queue, 3)
    # uart_send_check(uart, queue, 4)
    #Test 1 ends here-----------------------
    
    #2. Back-to-back sequence: send all samples together, then receive the results
    # print("Test 2 begins:")
    # samples = [
    #     4, 8, 12, 16, 20, 0,
    #     255, 255, 255, 255,
    #     0, 0, 0, 0,
    #     1, 2, 3, 4,
    #     100, 200, 50, 150,
    #     255, 0, 255, 0,
    #     17, 83, 129, 241,
    #     10, 20, 30, 40
    # ]

    # current_samples = deque([0, 0, 0, 0], maxlen=4)
    # expected = []

    # for sample in samples:
    #     current_samples.append(sample)
    #     expected.append(sum(current_samples) // 4)

    # uart.write(bytes(samples))
    # received = list(uart.read(len(samples)))

    # print("Expected:", expected)
    # print("Received:", received)
    # print("PASSED" if received == expected else "FAILED")
    #Test 2 ends here-----------------------