'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog"
import { PlusCircle, UserCheck, Vote, Play, ArrowRight, Trash2 } from "lucide-react"

type Country = {
  name: string
  emoji: string
}

type MotionType = 
  | 'MODERATED_CAUCUS'
  | 'UNMODERATED_CAUCUS'
  | 'CONSULTATION_OF_THE_WHOLE'
  | 'ROUND_ROBIN'
  | 'SPEAKERS_LIST'
  | 'OPEN_DEBATE'
  | 'SUSPENSION_OF_THE_MEETING'
  | 'ADJOURNMENT_OF_THE_MEETING'
  | 'CLOSURE_OF_DEBATE'

type Motion = {
  id: string
  type: MotionType
  country: Country | null
  delegates?: number
  timePerDelegate?: { minutes: number; seconds: number }
  totalTime?: { minutes: number; seconds: number }
  votes: number
}

export default function MocionClient({ countries, sessionId }: { countries: Country[], sessionId: string }) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [isOpen, setIsOpen] = useState(false)
  const [isVoting, setIsVoting] = useState(false)
  const [motion, setMotion] = useState<Omit<Motion, 'id' | 'votes'>>({
    type: 'MODERATED_CAUCUS',
    country: null,
    delegates: 1,
    timePerDelegate: { minutes: 1, seconds: 0 },
    totalTime: { minutes: 1, seconds: 0 }
  })
  const [proposedMotions, setProposedMotions] = useState<Motion[]>([])
  const [searchTerm, setSearchTerm] = useState('')
  const [votingEnded, setVotingEnded] = useState(false)

  useEffect(() => {
    if (motion.type === 'MODERATED_CAUCUS' || motion.type === 'ROUND_ROBIN' || motion.type === 'SPEAKERS_LIST') {
      const totalSeconds = (motion.delegates || 0) * ((motion.timePerDelegate?.minutes || 0) * 60 + (motion.timePerDelegate?.seconds || 0))
      setMotion(prev => ({
        ...prev,
        totalTime: {
          minutes: Math.floor(totalSeconds / 60),
          seconds: totalSeconds % 60
        }
      }))
    }
  }, [motion.type, motion.delegates, motion.timePerDelegate])

  const filteredCountries = countries
    .filter(country => country.name.toLowerCase().includes(searchTerm.toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name))

  const hasTimeAttributes = ['MODERATED_CAUCUS', 'ROUND_ROBIN', 'SPEAKERS_LIST'].includes(motion.type)
  const hasTotalTimeOnly = ['UNMODERATED_CAUCUS', 'CONSULTATION_OF_THE_WHOLE', 'OPEN_DEBATE'].includes(motion.type)
  const hasNoAttributes = ['SUSPENSION_OF_THE_MEETING', 'ADJOURNMENT_OF_THE_MEETING', 'CLOSURE_OF_DEBATE'].includes(motion.type)

  const handleCreateMotion = () => {
    const newMotion: Motion = {
      ...motion,
      id: Date.now().toString(),
      votes: 0
    }
    setProposedMotions(prev => [...prev, newMotion])
    setIsOpen(false)
  }

  const handleVote = (id: string) => {
    setProposedMotions(prev => 
      prev.map(m => m.id === id ? { ...m, votes: m.votes + 1 } : m)
    )
  }

  const handleAsistenciaClick = () => {
    router.push(`/asistencia?sessionId=${sessionId}`)
  }

  const startVoting = () => {
    setIsVoting(true)
    setVotingEnded(false)
  }

  const endVoting = () => {
    setIsVoting(false)
    setVotingEnded(true)
    // Sort motions by votes in descending order
    setProposedMotions(prev => [...prev].sort((a, b) => b.votes - a.votes))
  }

  const goToDebate = () => {
    if (proposedMotions.length > 0) {
      const winningMotion = proposedMotions[0]
      router.push(`/motion-debate?motion=${encodeURIComponent(JSON.stringify(winningMotion))}`)
    }
  }

  const clearAllMotions = () => {
    setProposedMotions([])
    setVotingEnded(false)
  }

  return (
    <div className="p-4">
      <div className="flex flex-wrap justify-between gap-2 mb-4">
        <Button onClick={handleAsistenciaClick}>
          <UserCheck className="mr-2 h-4 w-4" /> Register Assistance
        </Button>
        <Dialog open={isOpen} onOpenChange={setIsOpen}>
          <DialogTrigger asChild>
            <Button>
              <PlusCircle className="mr-2 h-4 w-4" /> New Motion
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[425px]">
            <Card className="border-none shadow-none">
              <CardHeader>
                <CardTitle>Create New Motion</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="motion-type">Motion Type</Label>
                  <Select
                    value={motion.type}
                    onValueChange={(value: MotionType) => setMotion(prev => ({ ...prev, type: value }))}
                  >
                    <SelectTrigger id="motion-type">
                      <SelectValue placeholder="Select motion type" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="MODERATED_CAUCUS">Moderated Caucus</SelectItem>
                      <SelectItem value="UNMODERATED_CAUCUS">Unmoderated Caucus</SelectItem>
                      <SelectItem value="CONSULTATION_OF_THE_WHOLE">Consultation of the Whole</SelectItem>
                      <SelectItem value="ROUND_ROBIN">Round Robin</SelectItem>
                      <SelectItem value="SPEAKERS_LIST">Speakers List</SelectItem>
                      <SelectItem value="OPEN_DEBATE">Open Debate</SelectItem>
                      <SelectItem value="SUSPENSION_OF_THE_MEETING">Suspension of the Meeting</SelectItem>
                      <SelectItem value="ADJOURNMENT_OF_THE_MEETING">Adjournment of the Meeting</SelectItem>
                      <SelectItem value="CLOSURE_OF_DEBATE">Closure of Debate</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="country-search">Country</Label>
                  <Input
                    id="country-search"
                    placeholder="Search for a country"
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                  />
                  <Select
                    value={motion.country?.name || ''}
                    onValueChange={(value) => setMotion(prev => ({ ...prev, country: countries.find(c => c.name === value) || null }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select a country" />
                    </SelectTrigger>
                    <SelectContent>
                      {filteredCountries.map((country) => (
                        <SelectItem key={country.name} value={country.name}>
                          {country.emoji} {country.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                {(hasTimeAttributes || hasTotalTimeOnly) && (
                  <div className="space-y-2">
                    <Label>Total Time</Label>
                    <div className="flex space-x-2">
                      <Input
                        type="number"
                        placeholder="Minutes"
                        value={motion.totalTime?.minutes || 0}
                        onChange={(e) => setMotion(prev => ({ ...prev, totalTime: { ...prev.totalTime, minutes: parseInt(e.target.value) || 0 } }))}
                        disabled={hasTimeAttributes}
                      />
                      <Input
                        type="number"
                        placeholder="Seconds"
                        value={motion.totalTime?.seconds || 0}
                        onChange={(e) => setMotion(prev => ({ ...prev, totalTime: { ...prev.totalTime, seconds: parseInt(e.target.value) || 0 } }))}
                        disabled={hasTimeAttributes}
                      />
                    </div>
                  </div>
                )}

                {hasTimeAttributes && (
                  <>
                    <div className="space-y-2">
                      <Label htmlFor="delegates">Number of Delegates</Label>
                      <Input
                        id="delegates"
                        type="number"
                        value={motion.delegates || 0}
                        onChange={(e) => setMotion(prev => ({ ...prev, delegates: parseInt(e.target.value) || 0 }))}
                      />
                    </div>

                    <div className="space-y-2">
                      <Label>Time per Delegate</Label>
                      <div className="flex space-x-2">
                        <Input
                          type="number"
                          placeholder="Minutes"
                          value={motion.timePerDelegate?.minutes || 0}
                          onChange={(e) => setMotion(prev => ({ ...prev, timePerDelegate: { ...prev.timePerDelegate, minutes: parseInt(e.target.value) || 0 } }))}
                        />
                        <Input
                          type="number"
                          placeholder="Seconds"
                          value={motion.timePerDelegate?.seconds || 0}
                          onChange={(e) => setMotion(prev => ({ ...prev, timePerDelegate: { ...prev.timePerDelegate, seconds: parseInt(e.target.value) || 0 } }))}
                        />
                      </div>
                    </div>
                  </>
                )}

                <Button className="w-full" onClick={handleCreateMotion}>Create Motion</Button>
              </CardContent>
            </Card>
          </DialogContent>
        </Dialog>
        <Button onClick={startVoting} disabled={isVoting || proposedMotions.length === 0}>
          <Vote className="mr-2 h-4 w-4" /> Start Voting
        </Button>
        <Button onClick={endVoting} disabled={!isVoting}>
          <Play className="mr-2 h-4 w-4" /> End Voting
        </Button>
        {votingEnded && proposedMotions.length > 0 && (
          <Button onClick={goToDebate} className="bg-green-500 hover:bg-green-600">
            <ArrowRight className="mr-2 h-4 w-4" /> Go to Debate
          </Button>
        )}
        <Button onClick={clearAllMotions} variant="destructive">
          <Trash2 className="mr-2 h-4 w-4" /> Clear All Motions
        </Button>
      </div>

      <div className="space-y-4">
        <h2 className="text-2xl font-bold">Proposed Motions</h2>
        {proposedMotions.map((m, index) => (
          <Card key={m.id} className={index === 0 && votingEnded ? "border-green-500" : ""}>
            <CardContent className="flex justify-between items-center p-4">
              <div>
                <h3 className="font-bold">{m.type}</h3>
                <p>{m.country?.emoji} {m.country?.name}</p>
                {(m.totalTime || m.delegates) && (
                  <p>
                    {m.totalTime && `Total Time: ${m.totalTime.minutes}m ${m.totalTime.seconds}s`}
                    {m.delegates && ` | Delegates: ${m.delegates}`}
                  </p>
                )}
              </div>
              {isVoting && (
                <Button onClick={() => handleVote(m.id)}>
                  Vote ({m.votes})
                </Button>
              )}
              {votingEnded && (
                <span className="font-bold">Votes: {m.votes}</span>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}