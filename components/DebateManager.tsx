'use client'

import { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { PlayCircle, PauseCircle, StopCircle, PlusCircle, Trash2 } from 'lucide-react'

type Delegate = {
  id: string
  name: string
  country: string
}

type DebateManagerProps = {
  motion: {
    type: string
    topic?: string
    totalTime: { minutes: number; seconds: number }
    timePerDelegate?: { minutes: number; seconds: number }
  }
}

export default function DebateManager({ motion }: DebateManagerProps) {
  const [delegates, setDelegates] = useState<Delegate[]>([])
  const [currentDelegateIndex, setCurrentDelegateIndex] = useState(0)
  const [remainingTime, setRemainingTime] = useState(motion.totalTime)
  const [isTimerRunning, setIsTimerRunning] = useState(false)
  const [newDelegate, setNewDelegate] = useState({ name: '', country: '' })

  useEffect(() => {
    let timer: NodeJS.Timeout
    if (isTimerRunning && (remainingTime.minutes > 0 || remainingTime.seconds > 0)) {
      timer = setInterval(() => {
        setRemainingTime(prev => {
          if (prev.seconds === 0) {
            return { minutes: prev.minutes - 1, seconds: 59 }
          } else {
            return { ...prev, seconds: prev.seconds - 1 }
          }
        })
      }, 1000)
    } else if (remainingTime.minutes === 0 && remainingTime.seconds === 0) {
      setIsTimerRunning(false)
    }
    return () => clearInterval(timer)
  }, [isTimerRunning, remainingTime])

  const startTimer = () => setIsTimerRunning(true)
  const pauseTimer = () => setIsTimerRunning(false)
  const resetTimer = () => {
    setIsTimerRunning(false)
    setRemainingTime(motion.totalTime)
    setCurrentDelegateIndex(0)
  }

  const addDelegate = () => {
    if (newDelegate.name && newDelegate.country) {
      setDelegates([...delegates, { ...newDelegate, id: Date.now().toString() }])
      setNewDelegate({ name: '', country: '' })
    }
  }

  const removeDelegate = (id: string) => {
    setDelegates(delegates.filter(d => d.id !== id))
  }

  const nextDelegate = () => {
    if (currentDelegateIndex < delegates.length - 1) {
      setCurrentDelegateIndex(currentDelegateIndex + 1)
      if (motion.timePerDelegate) {
        setRemainingTime(motion.timePerDelegate)
      }
    }
  }

  return (
    <Card className="w-full max-w-2xl mx-auto mt-8">
      <CardHeader>
        <CardTitle>{motion.type}: {motion.topic}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="text-4xl font-bold text-center" aria-live="polite">
            {String(remainingTime.minutes).padStart(2, '0')}:{String(remainingTime.seconds).padStart(2, '0')}
          </div>
          <div className="flex justify-center space-x-2">
            <Button onClick={startTimer} disabled={isTimerRunning}>
              <PlayCircle className="mr-2 h-4 w-4" /> Start
            </Button>
            <Button onClick={pauseTimer} disabled={!isTimerRunning}>
              <PauseCircle className="mr-2 h-4 w-4" /> Pause
            </Button>
            <Button onClick={resetTimer}>
              <StopCircle className="mr-2 h-4 w-4" /> Reset
            </Button>
            <Button onClick={nextDelegate} disabled={currentDelegateIndex >= delegates.length - 1}>
              Next Delegate
            </Button>
          </div>

          <div className="space-y-2">
            <Label htmlFor="delegate-name">Delegate Name</Label>
            <Input
              id="delegate-name"
              value={newDelegate.name}
              onChange={(e) => setNewDelegate({ ...newDelegate, name: e.target.value })}
              placeholder="Enter delegate name"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="delegate-country">Delegate Country</Label>
            <Input
              id="delegate-country"
              value={newDelegate.country}
              onChange={(e) => setNewDelegate({ ...newDelegate, country: e.target.value })}
              placeholder="Enter delegate country"
            />
          </div>
          <Button onClick={addDelegate}>
            <PlusCircle className="mr-2 h-4 w-4" /> Add Delegate
          </Button>

          <div className="space-y-2">
            <h3 className="font-bold">Delegates List</h3>
            {delegates.map((delegate, index) => (
              <div key={delegate.id} className="flex justify-between items-center">
                <span className={index === currentDelegateIndex ? 'font-bold' : ''}>
                  {delegate.name} - {delegate.country}
                </span>
                <Button variant="destructive" size="sm" onClick={() => removeDelegate(delegate.id)}>
                  <Trash2 className="h-4 w-4" />
                  <span className="sr-only">Remove {delegate.name}</span>
                </Button>
              </div>
            ))}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

