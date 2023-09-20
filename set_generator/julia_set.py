from grpc_generated import set_generator_pb2, set_generator_pb2_grpc
import numpy as np
import grpc
import time

class JuliaSetGeneratorService(set_generator_pb2_grpc.JuliaSetGeneratorService):
    def GetSetAsHeightMap(self, request, context):
        start_time = time.time()
        height_map = _GetSetAsHeightMap(request.width, request.height, request.threshold, request.position)
        elapsed_time = time.time() - start_time
        print(f"{round(elapsed_time * 1000, 2)}ms")
        result = set_generator_pb2.HeightMapResponse(height_map=height_map.tolist(), position=request.position)
  
        return result
    
    def GetSetAsHeightMapStream(self, request, context):
        position  = request.position
        while True:
            fraction_part = position % 1
            # Slowdown at interesting region
            if fraction_part > 0.65 and fraction_part < 0.75:
                position += 0.001
            elif fraction_part > 0.45 and fraction_part < 0.65:
                position += 0.05
            else:
                position += 0.01
            start_time = time.time() 
            height_map = _GetSetAsHeightMap(request.width, request.height, request.threshold, position)
            elapsed_time = time.time() - start_time
            print(f"{round(elapsed_time * 1000, 2)}ms")
            result = set_generator_pb2.HeightMapResponse(height_map=height_map.tolist(), position=position)
            yield result
        
def _GetSetAsHeightMap(widthPoints: int, heightPoints: int, threshold: int, position: float):
    result = np.empty(widthPoints * heightPoints, dtype=np.uint8)
    width, height = 4, 4*heightPoints/widthPoints  # fix aspect ratio
    x_start, y_start = -width/2, -height/2  # an interesting region starts here

    # real (x) and imaginary (y) axis
    re = np.linspace(x_start, x_start + width, widthPoints)
    im = np.linspace(y_start, y_start + height, heightPoints)

    # we represent c as c = r*cos(a) + i*r*sin(a) = r*e^{i*a}
    r = 0.7
    a = 2*np.pi*position;
    cx, cy = r * np.cos(a), r * np.sin(a)  # the initial c number

    for i in range(heightPoints):
        for j in range(widthPoints):
            result[i*widthPoints+j] = _check_in_julia_set(re[j], im[i], cx, cy, threshold)
        
    return result

def _check_in_julia_set(zx: int, zy: int, const_x: int, const_y: int, threshold: int):
    """Calculates whether the number z[0] = zx + i*zy with a constant c = x + i*y
    belongs to the Julia set. In order to belong, the sequence 
    z[i + 1] = z[i]**2 + c, must not diverge after 'threshold' number of steps.
    The sequence diverges if the absolute value of z[i+1] is greater than 4.
    
    :param float zx: the x component of z[0]
    :param float zy: the y component of z[0]
    :param float cx: the x component of the constant c
    :param float cy: the y component of the constant c
    :param int threshold: the number of iterations to considered it converged
    """
    # initial conditions
    z = complex(zx, zy)
    c = complex(const_x, const_y)
    
    for i in range(threshold):
        z = z**2 + c
        if abs(z) > 4.:  # it diverged, taking 4 as arbitrary ceiling for determining the escape
            return i
        
    return threshold - 1  # it didn't diverge