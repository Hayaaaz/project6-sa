import os

print("Running workload...")
print("CUDA_VISIBLE_DEVICES =", os.environ.get("CUDA_VISIBLE_DEVICES"))
print("This simulates a model pinned to a MIG slice.")
