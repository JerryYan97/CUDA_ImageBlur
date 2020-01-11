
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

__global__
void blurKernel(unsigned char *Pout, unsigned char *Pin, int w, int h, int BLUR_SIZE)
{
	int colIdx = blockIdx.x * blockDim.x + threadIdx.x;
	int rowIdx = blockIdx.y * blockDim.y + threadIdx.y;

	if (colIdx < w && rowIdx < h)
	{
		int pixValR = 0;
		int pixValG = 0;
		int pixValB = 0;
		int pixCounter = 0;
		// Get the average of the surrounding BLUR_SIZE * BLUR_SIZE box.
		for (int blurRowIdxOffset = -BLUR_SIZE; blurRowIdxOffset < BLUR_SIZE + 1; blurRowIdxOffset++)
		{
			for (int blurColIdxOffset = -BLUR_SIZE; blurColIdxOffset < BLUR_SIZE + 1; blurColIdxOffset++)
			{
				int tarColIdx = colIdx + blurColIdxOffset;
				int tarRowIdx = rowIdx + blurRowIdxOffset;
				// Verify we have a valid image pixel
				if (tarColIdx >= 0 && tarColIdx < w && tarRowIdx >= 0 && tarRowIdx < h)
				{
					// pixVal += Pin[tarRowIdx * w + tarColIdx];
					int tarPixIdx = 3 * (tarRowIdx * w + tarColIdx);
					pixValR += Pin[tarPixIdx + 0];
					pixValG += Pin[tarPixIdx + 1];
					pixValB += Pin[tarPixIdx + 2];
					pixCounter++;
				}
			}
		}
		int channelIdx = 3 * (rowIdx * w + colIdx);
		Pout[channelIdx + 0] = (unsigned char)(pixValR / pixCounter);
		Pout[channelIdx + 1] = (unsigned char)(pixValG / pixCounter);
		Pout[channelIdx + 2] = (unsigned char)(pixValB / pixCounter);
		int a = 2;
		// Pout[rowIdx * w + colIdx] = (unsigned char)(pixVal / pixCounter);
	}
}


void Blur(unsigned char* Pout, unsigned char* Pin, int width, int height, int channel)
{
	unsigned char* d_Pin, *d_Pout;
	int size = width * height * channel * sizeof(unsigned char);

	cudaMalloc((void**)&d_Pin, size);
	cudaMemcpy(d_Pin, Pin, size, cudaMemcpyHostToDevice);

	cudaMalloc((void**)&d_Pout, size);

	dim3 dimGrid(ceil(width / 16.0), ceil(height / 16.0), 1);
	dim3 dimBlock(16, 16, 1);

	blurKernel << <dimGrid, dimBlock >> > (d_Pout, d_Pin, width, height, 3);

	cudaMemcpy(Pout, d_Pout, size, cudaMemcpyDeviceToHost);

	cudaFree(d_Pin);
	cudaFree(d_Pout);
}

int main()
{

	int w, h, n;
	unsigned char *data = stbi_load("rgba.png", &w, &h, &n, 0);
	unsigned char *oData = new unsigned char[w * h * n];

	Blur(oData, data, w, h, n);

	stbi_write_png("write.png", w, h, n, oData, 0);
	stbi_image_free(data);

    return 0;
}

