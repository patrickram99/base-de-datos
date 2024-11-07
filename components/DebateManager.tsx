'use client'

import { useState, useEffect } from 'react'
import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog"
import { X, Play, Pause, SkipForward } from "lucide-react"

type Country = {
  name: string
  emoji: string
}

type Motion = {
  type: string
  delegates?: number
  timePerDelegate?: { minutes: number; seconds: number }
  totalTime: { minutes: number; seconds: number }
  topic?: string
}

type Delegate = {
  id: string
  country: Country
}

export default function DebateManager({ motion, countries, onClose }: { motion: Motion, countries: Country[], onClose: () => void }) {
  const [delegates, setDelegates] = useState<Delegate[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [remainingTime, setRemainingTime] = useState(motion.totalTime)
  const [isRunning, setIsRunning] = useState(false)
  const [currentDelegateIndex, setCurrentDelegateIndex] = useState(0)
  const [delegateTime, setDelegateTime] = useState(motion.timePerDelegate || motion.totalTime)

  useEffect(() => {
    let interval: NodeJS.Timeout
    if (isRunning) {
      interval = setInterval(() => {
        setRemainingTime(prev => {
          if (prev.minutes === 0 && prev.seconds === 0) {
            clearInterval(interval)
            setIsRunning(false)
            return prev
          }
          if (prev.seconds === 0) {
            return { minutes: prev.minutes - 1, seconds: 59 }
          }
          return { ...prev, seconds: prev.seconds - 1 }
        })

        if (motion.type === 'MODERATED_CAUCUS' || motion.type === 'SPEAKERS_LIST') {
          setDelegateTime(prev => {
            if (prev.minutes === 0 && prev.seconds === 0) {
              nextDelegate()
              return motion.timePerDelegate || motion.totalTime
            }
            if (prev.seconds === 0) {
              return { minutes: prev.minutes - 1, seconds: 59 }
            }
            return { ...prev, seconds: prev.seconds - 1 }
          })
        }
      }, 1000)
    }
    return () => clearInterval(interval)
  }, [isRunning, motion.type, motion.timePerDelegate])

  const filteredCountries = countries
    .filter(country => country.name.toLowerCase().includes(searchTerm.toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name))

  const handleAddDelegate = (country: Country) => {
    if (delegates.length < (motion.delegates || Infinity)) {
      setDelegates([...delegates, { id: Date.now().toString(), country }])
      setSearchTerm('')
    }
  }

  const handleRemoveDelegate = (id: string) => {
    setDelegates(delegates.filter(delegate => delegate.id !== id))
  }

  const onDragEnd = (result: any) => {
    if (!result.destination) return
    const items = Array.from(delegates)
    const [reorderedItem] = items.splice(result.source.index, 1)
    items.splice(result.destination.index, 0, reorderedItem)
    setDelegates(items)
  }

  const toggleTimer = () => setIsRunning(!isRunning)

  const nextDelegate = () => {
    if (currentDelegateIndex < delegates.length - 1) {
      setCurrentDelegateIndex(currentDelegateIndex + 1)
      setDelegateTime(motion.timePerDelegate || motion.totalTime)
    } else {
      setIsRunning(false)
      onClose()
    }
  }

  const formatTime = (time: { minutes: number, seconds: number }) => {
    return `${time.minutes.toString().padStart(2, '0')}:${time.seconds.toString().padStart(2, '0')}`
  }

  return (
    <Dialog open={true} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[600px]">
        <Card className="border-none shadow-none">
          <CardHeader>
            <CardTitle>{motion.type}</CardTitle>
            <Button variant="outline" size="icon" onClick={onClose} className="absolute right-4 top-4">
              <X className="h-4 w-4" />
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            {motion.topic && <p className="font-semibold">Topic: {motion.topic}</p>}
            <div className="text-4xl font-bold text-center">
              {formatTime(remainingTime)}
            </div>
            {(motion.type === 'MODERATED_CAUCUS' || motion.type === 'SPEAKERS_LIST') && (
              <div className="text-2xl font-semibold text-center">
                Delegate Time: {formatTime(delegateTime)}
              </div>
            )}
            <div className="flex justify-center space-x-2">
              <Button onClick={toggleTimer}>
                {isRunning ? <Pause className="mr-2 h-4 w-4" /> : <Play className="mr-2 h-4 w-4" />}
                {isRunning ? 'Pause' : 'Start'}
              </Button>
              {(motion.type === 'MODERATED_CAUCUS' || motion.type === 'SPEAKERS_LIST') && (
                <Button onClick={nextDelegate}>
                  <SkipForward className="mr-2 h-4 w-4" /> Next Delegate
                </Button>
              )}
            </div>
            {(motion.type === 'MODERATED_CAUCUS' || motion.type === 'SPEAKERS_LIST') && (
              <>
                <div className="space-y-2">
                  <Label htmlFor="country-search">Add Delegate</Label>
                  <div className="relative">
                    <Input
                      id="country-search"
                      placeholder="Search for a country"
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                    />
                    {searchTerm && (
                      <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto">
                        {filteredCountries.map((country) => (
                          <div
                            key={country.name}
                            className="px-4 py-2 cursor-pointer hover:bg-gray-100"
                            onClick={() => handleAddDelegate(country)}
                          >
                            {country.emoji} {country.name}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
                <DragDropContext onDragEnd={onDragEnd}>
                  <Droppable droppableId="delegates">
                    {(provided) => (
                      <ul {...provided.droppableProps} ref={provided.innerRef} className="space-y-2">
                        {delegates.map((delegate, index) => (
                          <Draggable key={delegate.id} draggableId={delegate.id} index={index}>
                            {(provided) => (
                              <li
                                ref={provided.innerRef}
                                {...provided.draggableProps}
                                {...provided.dragHandleProps}
                                className={`flex justify-between items-center p-2 bg-gray-100 rounded ${index === currentDelegateIndex ? 'border-2 border-blue-500' : ''}`}
                              >
                                <span>{delegate.country.emoji} {delegate.country.name}</span>
                                <Button variant="outline" size="icon" onClick={() => handleRemoveDelegate(delegate.id)}>
                                  <X className="h-4 w-4" />
                                </Button>
                              </li>
                            )}
                          </Draggable>
                        ))}
                        {provided.placeholder}
                      </ul>
                    )}
                  </Droppable>
                </DragDropContext>
              </>
            )}
          </CardContent>
        </Card>
      </DialogContent>
    </Dialog>
  )
}