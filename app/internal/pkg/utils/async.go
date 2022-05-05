package utils

import (
	"time"

	"github.com/schollz/progressbar/v3"
)

type asyncResult struct {
	err    error
	output interface{}
}

type AsyncFunction func() (interface{}, error)

func AsyncProgressWait(fn AsyncFunction, pbar *progressbar.ProgressBar) (interface{}, error) {
	done := make(chan asyncResult)

	go func() {
		output, err := fn()
		done <- asyncResult{
			output: output,
			err:    err,
		}
	}()

	for {
		select {
		case result := <-done:
			if result.err != nil {
				return nil, result.err
			}

			return result.output, nil
		default:
			if pbar != nil {
				pbar.Add(1)
			}

			time.Sleep(5 * time.Millisecond)
		}
	}
}
