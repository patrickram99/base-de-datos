'use client'

import { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ScrollArea } from "@/components/ui/scroll-area"

import { PlayCircle, PauseCircle, StopCircle, PlusCircle, Trash2, Search, ChevronRight } from 'lucide-react'

type Delegate = {
  id: string
  country: {
    name: string
    emoji: string
  }
}

type Motion = {
  id: string
  type: string
  country: { name: string; emoji: string } | null
  delegates?: number
  timePerDelegate?: { minutes: number; seconds: number }
  totalTime: { minutes: number; seconds: 0 }
  votes: number
  topic?: string
}

type DesarrolloClientProps = {
  delegates: Delegate[]
  motionParam: string
}

export default function DesarrolloClient({ delegates, motionParam }: DesarrolloClientProps) {
  const [motion, setMotion] = useState<Motion | null>(null)
  const [speakersList, setSpeakersList] = useState<Delegate[]>([])
  const [currentDelegateIndex, setCurrentDelegateIndex] = useState(0)
  const [remainingTime, setRemainingTime] = useState({ minutes: 0, seconds: 0 })
  const [isTimerRunning, setIsTimerRunning] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')
  const [filteredDelegates, setFilteredDelegates] = useState<Delegate[]>(delegates)

  useEffect(() => {
    if (motionParam) {
      const decodedMotion = JSON.parse(decodeURIComponent(motionParam)) as Motion
      setMotion(decodedMotion)
      setRemainingTime(decodedMotion.totalTime)
    }
  }, [motionParam])

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

  useEffect(() => {
    const filtered = delegates.filter(
      delegate =>
        delegate.country.name.toLowerCase().includes(searchTerm.toLowerCase())
    )
    setFilteredDelegates(filtered)
  }, [searchTerm, delegates])

  const startTimer = () => setIsTimerRunning(true)
  const pauseTimer = () => setIsTimerRunning(false)
  const resetTimer = () => {
    setIsTimerRunning(false)
    setRemainingTime(motion?.totalTime || { minutes: 0, seconds: 0 })
    setCurrentDelegateIndex(0)
  }

  const addDelegate = (delegate: Delegate) => {
    if (!speakersList.some(d => d.id === delegate.id)) {
      setSpeakersList([...speakersList, delegate])
    }
  }

  const removeDelegate = (id: string) => {
    setSpeakersList(speakersList.filter(d => d.id !== id))
  }

  const nextDelegate = () => {
    if (currentDelegateIndex < speakersList.length - 1) {
      setCurrentDelegateIndex(currentDelegateIndex + 1)
      if (motion?.timePerDelegate) {
        setRemainingTime(motion.timePerDelegate)
      }
    }
  }

  if (!motion) {
    return <div>Cargando...</div>
  }

  return (
    <div className="container mx-auto p-4">
      <Card className="w-full max-w-4xl mx-auto">
        <CardHeader>
          <CardTitle className="text-2xl md:text-3xl text-center">{motion.type}: {motion.topic}</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            <div className="text-5xl md:text-6xl font-bold text-center">
              {String(remainingTime.minutes).padStart(2, '0')}:{String(remainingTime.seconds).padStart(2, '0')}
            </div>
            <div className="flex flex-wrap justify-center gap-2">
              <Button onClick={startTimer} disabled={isTimerRunning}>
                <PlayCircle className="mr-2 h-4 w-4" /> Iniciar
              </Button>
              <Button onClick={pauseTimer} disabled={!isTimerRunning}>
                <PauseCircle className="mr-2 h-4 w-4" /> Pausar
              </Button>
              <Button onClick={resetTimer}>
                <StopCircle className="mr-2 h-4 w-4" /> Reiniciar
              </Button>
              <Button onClick={nextDelegate} disabled={currentDelegateIndex >= speakersList.length - 1}>
                <ChevronRight className="mr-2 h-4 w-4" /> Siguiente
              </Button>
            </div>

            {motion.type !== 'UNMODERATED_CAUCUS' && (
              <div className="grid md:grid-cols-2 gap-4">
                <div className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="delegate-search">Buscar Delegados</Label>
                    <div className="relative">
                      <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                      <Input
                        id="delegate-search"
                        placeholder="Buscar por país"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="pl-8"
                      />
                    </div>
                  </div>

                  <ScrollArea className="h-[200px] rounded-md border p-2">
                    {filteredDelegates.map((delegate) => (
                      <div key={delegate.id} className="flex justify-between items-center py-2">
                        <span>
                          {delegate.country.emoji} {delegate.country.name}
                        </span>
                        <Button size="sm" onClick={() => addDelegate(delegate)}>
                          <PlusCircle className="h-4 w-4" />
                        </Button>
                      </div>
                    ))}
                  </ScrollArea>
                </div>

                <div className="space-y-2">
                  <h3 className="font-bold text-lg">Lista de Oradores</h3>
                  <ScrollArea className="h-[200px] rounded-md border p-2">
                    {speakersList.map((delegate, index) => (
                      <div key={delegate.id} className="flex justify-between items-center py-2">
                        <span className={index === currentDelegateIndex ? 'font-bold' : ''}>
                          {delegate.country.emoji} {delegate.country.name}
                        </span>
                        <Button variant="destructive" size="sm" onClick={() => removeDelegate(delegate.id)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    ))}
                  </ScrollArea>
                </div>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

