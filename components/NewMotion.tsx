'use client'

import { useState, useEffect } from 'react'
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem } from "@/components/ui/command"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Check, ChevronsUpDown } from "lucide-react"
import { cn } from "@/lib/utils"

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

type Time = { minutes: number; seconds: number }

type Country = {
  name: string
  emoji: string
}

type Motion = {
  type: MotionType
  numberOfDelegates: number
  timePerDelegate: Time
  totalTime: Time
  country: string
}

type NewMotionFormProps = {
  countries?: Country[]
}

export default function NewMotionForm({ countries = [] }: NewMotionFormProps) {
  const [motion, setMotion] = useState<Motion>({
    type: 'MODERATED_CAUCUS',
    numberOfDelegates: 0,
    timePerDelegate: { minutes: 0, seconds: 0 },
    totalTime: { minutes: 0, seconds: 0 },
    country: ''
  })
  const [open, setOpen] = useState(false)

  const sortedCountries = Array.isArray(countries) 
    ? [...countries].sort((a, b) => a.name.localeCompare(b.name))
    : []

  const motionConfig = {
    'MODERATED_CAUCUS': { delegates: true, timePerDelegate: true, totalTime: 'auto' },
    'UNMODERATED_CAUCUS': { delegates: false, timePerDelegate: false, totalTime: true },
    'CONSULTATION_OF_THE_WHOLE': { delegates: false, timePerDelegate: false, totalTime: true },
    'ROUND_ROBIN': { delegates: true, timePerDelegate: true, totalTime: 'auto' },
    'SPEAKERS_LIST': { delegates: true, timePerDelegate: true, totalTime: 'auto' },
    'OPEN_DEBATE': { delegates: false, timePerDelegate: false, totalTime: true },
    'SUSPENSION_OF_THE_MEETING': { delegates: false, timePerDelegate: false, totalTime: false },
    'ADJOURNMENT_OF_THE_MEETING': { delegates: false, timePerDelegate: false, totalTime: false },
    'CLOSURE_OF_DEBATE': { delegates: false, timePerDelegate: false, totalTime: false }
  }

  useEffect(() => {
    if (motionConfig[motion.type].totalTime === 'auto') {
      const totalSeconds = motion.numberOfDelegates * (motion.timePerDelegate.minutes * 60 + motion.timePerDelegate.seconds)
      const minutes = Math.floor(totalSeconds / 60)
      const seconds = totalSeconds % 60
      setMotion(prev => ({ ...prev, totalTime: { minutes, seconds } }))
    }
  }, [motion.type, motion.numberOfDelegates, motion.timePerDelegate])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Submitted motion:', motion)
    // Here you would typically send the motion data to your backend or state management system
  }

  const updateMotion = (field: keyof Motion, value: any) => {
    setMotion(prev => ({ ...prev, [field]: value }))
  }

  const renderTimeInputs = (field: 'timePerDelegate' | 'totalTime') => (
    <div className="grid grid-cols-2 gap-2">
      <div>
        <Label htmlFor={`${field}-minutes`}>Minutes</Label>
        <Input
          type="number"
          id={`${field}-minutes`}
          min="0"
          value={motion[field].minutes}
          onChange={(e) => updateMotion(field, { ...motion[field], minutes: parseInt(e.target.value) || 0 })}
          disabled={!motionConfig[motion.type][field === 'timePerDelegate' ? 'timePerDelegate' : 'totalTime']}
          className={!motionConfig[motion.type][field === 'timePerDelegate' ? 'timePerDelegate' : 'totalTime'] ? 'opacity-50' : ''}
        />
      </div>
      <div>
        <Label htmlFor={`${field}-seconds`}>Seconds</Label>
        <Input
          type="number"
          id={`${field}-seconds`}
          min="0"
          max="59"
          value={motion[field].seconds}
          onChange={(e) => updateMotion(field, { ...motion[field], seconds: parseInt(e.target.value) || 0 })}
          disabled={!motionConfig[motion.type][field === 'timePerDelegate' ? 'timePerDelegate' : 'totalTime']}
          className={!motionConfig[motion.type][field === 'timePerDelegate' ? 'timePerDelegate' : 'totalTime'] ? 'opacity-50' : ''}
        />
      </div>
    </div>
  )

  return (
    <Card className="w-full max-w-lg">
      <CardHeader>
        <CardTitle>Create New Motion</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label htmlFor="motion-type">Motion Type</Label>
            <Select
              value={motion.type}
              onValueChange={(value: MotionType) => updateMotion('type', value)}
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

          <div>
            <Label htmlFor="country-select">Country</Label>
            <Popover open={open} onOpenChange={setOpen}>
              <PopoverTrigger asChild>
                <Button
                  variant="outline"
                  role="combobox"
                  aria-expanded={open}
                  className="w-full justify-between"
                >
                  {motion.country
                    ? sortedCountries.find((country) => country.name === motion.country)?.emoji + " " + motion.country
                    : "Select country..."}
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-full p-0">
                <Command>
                  <CommandInput placeholder="Search country..." />
                  <CommandEmpty>No country found.</CommandEmpty>
                  <CommandGroup>
                    {sortedCountries.map((country) => (
                      <CommandItem
                        key={country.name}
                        onSelect={() => {
                          updateMotion('country', country.name === motion.country ? "" : country.name)
                          setOpen(false)
                        }}
                      >
                        <Check
                          className={cn(
                            "mr-2 h-4 w-4",
                            motion.country === country.name ? "opacity-100" : "opacity-0"
                          )}
                        />
                        {country.emoji} {country.name}
                      </CommandItem>
                    ))}
                  </CommandGroup>
                </Command>
              </PopoverContent>
            </Popover>
          </div>

          <div>
            <Label htmlFor="number-of-delegates">Number of Delegates</Label>
            <Input
              type="number"
              id="number-of-delegates"
              min="0"
              value={motion.numberOfDelegates}
              onChange={(e) => updateMotion('numberOfDelegates', parseInt(e.target.value) || 0)}
              disabled={!motionConfig[motion.type].delegates}
              className={!motionConfig[motion.type].delegates ? 'opacity-50' : ''}
            />
          </div>

          <div>
            <Label>Time per Delegate</Label>
            {renderTimeInputs('timePerDelegate')}
          </div>

          <div>
            <Label>Total Time</Label>
            {renderTimeInputs('totalTime')}
          </div>

          <Button type="submit" className="w-full">Create Motion</Button>
        </form>
      </CardContent>
    </Card>
  )
}