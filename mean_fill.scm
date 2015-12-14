; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; This script creates a new layer on which contiguous regions of the
; selection are filled with the mean (average) value of that region.
; 
; Special thanks to Rob Antonishen for providing optimizations and
; making the operation UNDO-able

(define (script-fu-sg-mean-fill orig-image drawable)
  (let* (
      (width (car (gimp-image-width orig-image)))
      (height (car (gimp-image-height orig-image)))
      (orig-selection 0)
      (layer 0)
      (raw-selection 0)
      (selection 0)
      (x 0)
      (y 0)
      (bounds '())     
      (orig-drawable drawable)
      (image (car (gimp-image-duplicate orig-image)))
      (drawable (car (gimp-image-get-active-layer image)))
      (buffer "sgmfbuffer")
      (selection-drawable 0)
      )
   
    (gimp-image-undo-group-start orig-image)
    (gimp-image-undo-disable image)
    (gimp-context-push)
    (set! raw-selection (car (gimp-selection-save image)))
    (set! orig-selection (car (gimp-selection-save orig-image)))
    (set! selection (car (gimp-channel-copy raw-selection)))
    (gimp-image-add-channel image selection -1)
    (gimp-selection-none image)
    (gimp-threshold selection 127 255)
    (gimp-image-set-active-layer image drawable)
    (set! layer (car (gimp-layer-new-from-drawable drawable image)))
    (gimp-image-add-layer image layer -1)
    (gimp-layer-add-alpha layer)
    (gimp-drawable-fill layer TRANSPARENT-FILL)
    (gimp-selection-load selection)
    (set! selection-drawable (car (gimp-image-get-selection image)))
    (while (< y height)
      (while (< x width)
        (if (> (car (gimp-selection-value image x y)) 127)
          (begin
            (gimp-fuzzy-select selection x y 127 CHANNEL-OP-INTERSECT FALSE FALSE 0 FALSE)
            (gimp-context-set-foreground
                (list (car (gimp-histogram drawable HISTOGRAM-RED 0 255))
                      (car (gimp-histogram drawable HISTOGRAM-GREEN 0 255))
                      (car (gimp-histogram drawable HISTOGRAM-BLUE 0 255))))
            (gimp-edit-fill layer FOREGROUND-FILL)
            (gimp-channel-combine-masks selection selection-drawable CHANNEL-OP-SUBTRACT 0 0)
            (gimp-selection-load selection)
            (gimp-rect-select image x y width 1 CHANNEL-OP-INTERSECT FALSE 0)
            (if (= (car (set! bounds (gimp-selection-bounds image))) TRUE)
              (set! x (cadr bounds))
              (set! x width)              )
            (gimp-selection-load selection)
            (if (= (car (set! bounds (gimp-selection-bounds image))) TRUE)
              (begin
                (set! width (cadddr bounds))
                (set! y (max y (caddr bounds)))
                (set! height (cadr (cdddr bounds)))                )
              (begin
                (set! x width))))
          (begin
            (set! x 0)
            (gimp-rect-select image x y width 1 CHANNEL-OP-INTERSECT FALSE 0)
            (if (= (car (set! bounds (gimp-selection-bounds image))) TRUE)
              (set! x (cadr bounds))
              (set! x width))
            (gimp-selection-load selection)))
        (gimp-progress-pulse))
      (if (= (car (set! bounds (gimp-selection-bounds image))) TRUE)
        (begin
          (set! x (cadr bounds))
          (set! width (cadddr bounds))
          (set! y (max (+ y 1) (caddr bounds)))
          (set! height (cadr (cdddr bounds))))
        (begin
          (set! x width)
          (set! y height))))
    (gimp-selection-load raw-selection)
    (gimp-image-remove-channel image selection)
    (gimp-image-remove-channel image raw-selection)
   
    (set! buffer (car (gimp-edit-named-copy layer buffer)))
    (set! layer (car (gimp-layer-new-from-drawable orig-drawable orig-image)))
    (gimp-image-add-layer orig-image layer -1)
    (gimp-layer-add-alpha layer)
    (gimp-drawable-fill layer TRANSPARENT-FILL)
    (gimp-floating-sel-anchor (car (gimp-edit-named-paste layer buffer FALSE)))
   
    (gimp-displays-flush)
    (gimp-context-push)
    (gimp-progress-end)
    (gimp-selection-load orig-selection)
    (gimp-image-remove-channel orig-image orig-selection)
    (gimp-image-undo-enable image)
    (gimp-image-undo-group-end orig-image)
    (gimp-image-delete image)
   
    (gimp-image-set-active-layer orig-image orig-drawable)))

(script-fu-register "script-fu-sg-mean-fill"
  "Mean Fill"
  "Fill contiguous regions with the average of the region"
  "Raphael Sprenger"
  "Raphael Sprenger"
  "12/14/2015"
  "RGB*"
  SF-IMAGE "Image" 0
  SF-DRAWABLE "Drawable" 0
  )
(script-fu-menu-register "script-fu-sg-mean-fill"
  "<Image>/Filters/Misc"
  )
