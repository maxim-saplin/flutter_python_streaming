from grpc_generated import set_generator_pb2, set_generator_pb2_grpc
import numpy as np
import time
from numba import jit

class JuliaSetGeneratorService(set_generator_pb2_grpc.JuliaSetGeneratorService):
    def GetSetAsHeightMap(self, request, context):
        # Example of debuging and fixing
        # height_map = GetSet(request.width, request.height)
        height_map = _GetSetAsHeightMap(request.width, request.height, request.threshold, request.position)

        result = set_generator_pb2.HeightMapResponse(height_map=height_map.tolist())
  
        # result = set_generator_pb2.HeightMapResponse(height_map=flattened.astype(np.float32).tolist())
        return result
        
# @jit(nopython=True)
def _GetSetAsHeightMap(widthPoints: int, heightPoints: int, threshold: int, position: float):
    start_time = time.time()  # start timing
    result = np.empty(widthPoints * heightPoints, dtype=np.int32)
    x_start, y_start = -2, -2  # an interesting region starts here
    width, height = 4, 4*widthPoints/heightPoints  # for 4 units up and right

    # real and imaginary axis
    re = np.linspace(x_start, x_start + width, widthPoints)
    # rePixel = np.linspace(0, widthPoints, widthPoints)
    im = np.linspace(y_start, y_start + height, heightPoints)
    # imPixel = np.linspace(y_start, y_start + round(heightPoints / height), heightPoints)

    # we represent c as c = r*cos(a) + i*r*sin(a) = r*e^{i*a}
    r = 0.7
    #a = np.linspace(0, 2*np.pi, 100)
    a = 2*np.pi*position;

    # @jit(nopython=True)
    # def get_julia_row(re, im, const_x, const_y, threshold):
    #     X = np.empty(len(im))
    #     for j in range(len(im)):
    #         X[j] = _check_in_julia_set(re, im[j], const_x, const_y, threshold)
    #     return X
    
    def get_julia_row_inplace(i, re, im, const_x, const_y, threshold):
        for j in range(heightPoints):
            result[i*widthPoints+j] = _check_in_julia_set(re, im[j], const_x, const_y, threshold)

    cx, cy = r * np.cos(a), r * np.sin(a)  # the initial c number

    for i in range(widthPoints):
        get_julia_row_inplace(i, re[i], im, cx, cy, threshold)
        
    elapsed_time = time.time() - start_time
    print(f"{round(elapsed_time * 1000, 2)}ms")
        
    return result

# @jit(nopython=True)
def _check_in_julia_set(zx, zy, const_x, const_y, threshold):
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
        if abs(z) > 4.:  # it diverged
            return i
        
    return threshold - 1  # it didn't diverge