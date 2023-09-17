import sys
from concurrent import futures 
import grpc
from grpc_health.v1 import health_pb2_grpc
from grpc_health.v1 import health
from grpc_generated import set_generator_pb2_grpc
from julia_set import JuliaSetGeneratorService  

def serve():
  DEFAULT_PORT = 50055
  # Get the port number from the command line parameter    
  port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
  HOST = f'localhost:{port}'

  server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

  set_generator_pb2_grpc.add_JuliaSetGeneratorServiceServicer_to_server(JuliaSetGeneratorService(), server)
  health_pb2_grpc.add_HealthServicer_to_server(health.HealthServicer(), server)

  server.add_insecure_port(HOST)
  print(f"gRPC server started and listening on {HOST}")
  server.start()
  server.wait_for_termination()
  
if __name__ == '__main__':
  serve()  
