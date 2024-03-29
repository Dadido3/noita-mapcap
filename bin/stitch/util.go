// Copyright (c) 2019-2024 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"fmt"
	"image"
	"os"
	"sync"
)

// QuickSelect returns the kth smallest element of the given unsorted list.
// This is faster than sorting the list and then selecting the wanted element.
//
// Source: https://rosettacode.org/wiki/Quickselect_algorithm#Go
func QuickSelectUInt8(list []uint8, k int) uint8 {
	for {
		// Partition.
		px := len(list) / 2
		pv := list[px]
		last := len(list) - 1
		list[px], list[last] = list[last], list[px]

		i := 0
		for j := 0; j < last; j++ {
			if list[j] < pv {
				list[i], list[j] = list[j], list[i]
				i++
			}
		}

		// Select.
		if i == k {
			return pv
		}
		if k < i {
			list = list[:i]
		} else {
			list[i], list[last] = list[last], list[i]
			list = list[i+1:]
			k -= i + 1
		}
	}
}

// Source: https://gist.github.com/sergiotapia/7882944
func GetImageFileDimension(imagePath string) (int, int, error) {
	file, err := os.Open(imagePath)
	if err != nil {
		return 0, 0, fmt.Errorf("can't open file %v: %w", imagePath, err)
	}
	defer file.Close()

	image, _, err := image.DecodeConfig(file)
	if err != nil {
		return 0, 0, fmt.Errorf("error decoding config of image file %v: %w", imagePath, err)
	}

	return image.Width, image.Height, nil
}

func GridifyRectangle(rect image.Rectangle, gridSize int) (result []image.Rectangle) {
	for y := DivideFloor(rect.Min.Y, gridSize); y <= DivideCeil(rect.Max.Y-1, gridSize); y++ {
		for x := DivideFloor(rect.Min.X, gridSize); x <= DivideCeil(rect.Max.X-1, gridSize); x++ {
			tempRect := image.Rect(x*gridSize, y*gridSize, (x+1)*gridSize, (y+1)*gridSize)
			intersection := tempRect.Intersect(rect)
			if !intersection.Empty() {
				result = append(result, intersection)
			}
		}
	}

	return
}

// Integer division that rounds to the next integer towards negative infinity.
func DivideFloor(a, b int) int {
	temp := a / b

	if ((a ^ b) < 0) && (a%b != 0) {
		return temp - 1
	}

	return temp
}

// Integer division that rounds to the next integer towards positive infinity.
func DivideCeil(a, b int) int {
	temp := a / b

	if ((a ^ b) >= 0) && (a%b != 0) {
		return temp + 1
	}

	return temp
}

// https://gist.github.com/cstockton/d611ced26bb6b4d3f7d4237abb8613c4
type LimitGroup struct {
	wg   sync.WaitGroup
	mu   *sync.Mutex
	c    *sync.Cond
	l, n int
}

func NewLimitGroup(n int) *LimitGroup {
	mu := new(sync.Mutex)
	return &LimitGroup{
		mu: mu,
		c:  sync.NewCond(mu),
		l:  n,
		n:  n,
	}
}

func (lg *LimitGroup) Add(delta int) {
	lg.mu.Lock()
	defer lg.mu.Unlock()
	if delta > lg.l {
		panic(`LimitGroup: delta must not exceed limit`)
	}
	for lg.n < 1 {
		lg.c.Wait()
	}
	lg.n -= delta
	lg.wg.Add(delta)
}

func (lg *LimitGroup) Done() {
	lg.mu.Lock()
	defer lg.mu.Unlock()
	lg.n++
	lg.c.Signal()
	lg.wg.Done()
}

func (lg *LimitGroup) Wait() { lg.wg.Wait() }
