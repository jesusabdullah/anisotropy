from __future__ import division

import tablib
from math import pi

# csv.reader and tablib aren't smart enough to read in numbers as numbers.
# Therefore, I map this over the strings in the rows spat out by csv.reader.
def str2num(string):
    import re

    if re.match('^-?\d*\.\d*$', string):
        return float(string)
    elif re.match('^-?\d+$', string):
        return int(string)
    else:
        return string


def import_raw_data(filename):
    import csv

    data = tablib.Dataset()
    for row in csv.reader(open(filename, 'r')):
        data.append( map(str2num, row) )

    data.headers = ( 'logger_id'
                   , 'day'
                   , 'hourmin'
                   , 'sec'
                   , 'needletemp'
                   , 'reftemp'
                   , 'volts'
                   , 'timer')

    return data

def unique(col):
    return list(set(col))


# Time is kept in two ints: one of the form hhmm, and the other in s.
# This function converts those to absolute seconds, and rebuilds the
# table appropriately.
def hms_to_s(data):
    # This bit here converts hhmm to seconds and adds to s.
    # It doesn't account for changes in the julian days.
    # Just don't test @ midnight, I guess.
    def convert(hourmin, sec):
        return 60*(hourmin%100) + sec + 3600*(hourmin//100 )

    def sieve(st):
        return (st != 'hourmin') and (st != 'sec')

    sec = map(lambda t: convert(t[0], t[1]), 
                   zip(data['hourmin'], data['sec']))

    new_data = zip(sec, *map( lambda h: data[h],
                               filter(sieve, data.headers) ))
    new_headers = ['sec']+filter(sieve, data.headers)
    return tablib.Dataset(*new_data, headers=new_headers)


def tab_filter(data, header, testfxn):
    new_data = [];
    for (i, pt) in enumerate(data[header]):
        if testfxn(pt):
            new_data.append(data[i])
    return tablib.Dataset(*new_data, headers=data.headers)


def tab_pprint(data):
    width = 2 + max(map(lambda st: len(st), data.headers))

    def padder(st):
        l = len(str(st))
        return st + (width-l)*" " if l <= width else st[:width]

    print " | ".join(map(padder,data.headers))
    print "-"*((width+2)*len(data.headers)-1)
    for row in data:
        print " | ".join(map(padder,map(str,row)))


def tab_plot(data, x_header, y_headers = None, fit=None ):
    import matplotlib.pyplot as pyplot

    headers = filter(lambda h: h != x_header, data.headers if y_headers == None else y_headers)

    xs = [ data[x_header] for header in headers ]
    ys = [ data[header] for header in headers]


    if (fit != None):
        from numpy import arange, exp, log, polyval
        more_xs = arange(data[x_header][1],data[x_header][-1])
        more_ys = polyval(fit,log(more_xs))
        xs+=[more_xs]
        ys+=[more_ys]

    pyplot.semilogx(*reduce(lambda a, b: a+b, zip(xs,ys)))
    pyplot.xlabel(x_header)
    pyplot.ylabel('Everything Else')
    pyplot.show()
    return data


#Repeats code from hms_to_s, or whatever I called that fxn.
#Ideally, I would generalize the ideas of, "do something with
#these columns, generate THIS column" and "Get rid of these
#columns.
def relative_time(data, h_abs="sec", h_rel="sec"):
    from numpy import array

    t_actual = data[h_abs]
    t_zero = t_actual[0]

    t_relative = list(array(t_actual) - t_zero)

    def sieve(st):
        return (st != h_abs)

    new_data = zip(t_relative, *map( lambda h: data[h],
                                     filter(sieve, data.headers) ))

    new_headers = [h_rel]+filter(sieve, data.headers)

    return tablib.Dataset(*new_data, headers=new_headers)



#A class of tools for splitting data up
class Splitters(object):

    #You change your mind like a girl changes clothes!
    @staticmethod
    def hot_and_cold(data):
        from numpy import array, floor
        from scipy.optimize import curve_fit
       

        def fit(x, a, b, c):
            y = map(lambda x: (b if (x-a) > 0 else 0) - c, x)
            return array(y)

        split = int(floor(curve_fit(fit,
                                    data['sec'],
                                    data['volts'],
                                    ( 0.5*(data['sec'][0]+data['sec'][1]),
                                      data['volts'][0],
                                      0 ))[0][0]))

        hot = tablib.Dataset( *data[slice(None, split, None)], 
                              headers=data.headers)
        cold = tablib.Dataset( *data[slice(split, None, None)],
                              headers=data.headers)
        return ( hot, cold )

    @staticmethod
    def manual(data, header, value):
        a = tab_filter(data, header, lambda x: x < value)
        b = tab_filter(data, header, lambda x: x >= value)
        return (a, b)


def linreg(data, xheader = 'sec', yheader = 'needletemp' ):
    from numpy import polyfit, log
    return polyfit(log(data[xheader][1:]), data[yheader][1:], 1)


def q(data):
    from numpy import average

    # I'm not sure what these constants mean, but based on the equation
    # I can make a pretty good guess!
    r_r = 10.6 #needle radius?
    r_h = 142.2 #resistance?
    l = 0.120 #needle length?

    volts = float(average(data['volts']))

    return ((volts/1000)**2.0 * r_h) / (l*r_r**2.0)


def heating_curve(data, q):
    const = linreg(data)[0]
    return q/4.0/pi/float(const)


def cooling_curve(cool_data, q):
    const = linreg(cool_data)[0]
    return -q/4/pi/float(const)


#applies mcgaw cooling curve.
def mcgaw(data, k_hot, q_hot, hot_period):
    from math import exp, log, pi

    correction = 4*pi*q_hot*k_hot*log( (exp(data['sec'][-1])+ hot_period) /
                                       hot_period)

    #print data['sec'][-1]
    #print hot_period
    #print correction

    newtemps = map( lambda x: x - correction, data['needletemp'])


    new_data = [];
    new_headers = data.headers

    for header in data.headers:
        if header == 'needletemp':
            #print "ding!"
            new_data.append(newtemps)
        else:
            new_data.append(data[header])

    #transposition!
    new_data = zip(*new_data)

    return tablib.Dataset(*new_data, headers=new_headers)
    
#Lachenbruch's Time Correction from a 1957 paper.
#Haven't been able to find said paper. Whatever.
def lachenbruch(data, dt):
    from numpy import exp, log

    data['needletemp'] = list(log(exp(data['needletemp']) - dt))

    return data
