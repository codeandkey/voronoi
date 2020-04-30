--- Event queue

local eq = {}

function par(i)
    return math.floor(i / 2)
end

function eq.create()
    return {
        count = 0,
        buf = {},
    }
end

--- Returns true if a is strictly higher priority than b.
function eq.cmp(a, b)
    if a.y < b.y then
        return true
    end

    if a.y == b.y and a.x < b.x then
        return true
    end

    return false
end

function eq.push(q, ev)
    -- increment count, add event to end
    q.count = q.count + 1
    q.buf[q.count] = ev

    -- shift event up to maintain order
    local cur = q.count

    while cur > 1 do
        -- stop shifting if order is OK
        if eq.cmp(q.buf[par(cur)].point, q.buf[cur].point) then
            break
        end

        -- continue shift
        q.buf[par(cur)], q.buf[cur] = q.buf[cur], q.buf[par(cur)]
        cur = par(cur)
    end
end

function eq.pop(q)
    if q.count == 0 then
        return nil
    end

    local ret = q.buf[1]

    q.buf[1] = q.buf[q.count]
    q.count = q.count - 1

    -- shift new top down to maintain order
    local cur = 1
    while cur * 2 <= q.count do
        local to_swap = cur * 2

        -- swap with RC if the priority is higher
        if cur * 2 + 1 <= q.count and eq.cmp(q.buf[cur * 2 + 1].point, q.buf[cur * 2].point) then
            to_swap = cur * 2 + 1
        end

        if eq.cmp(q.buf[to_swap].point, q.buf[cur].point) then
            q.buf[cur], q.buf[to_swap] = q.buf[to_swap], q.buf[cur]
            cur = to_swap
        else
            -- no swap necessary. stop shifting
            break
        end
    end

    return ret
end

function eq.remove(q, ev)
    -- First find the event.
    local loc = nil
    for i=1,q.count do
        if q.buf[i] == ev then
            loc = i
        end
    end

    if loc == nil then
        return
    end

    --print(string.format('removing ev: %s at (%d %d) [loc=%d]', ev.type, ev.point.x, ev.point.y, loc))

    if loc == q.count then
        q.buf[loc] = nil
        q.count = q.count - 1
        return
    end

    local ret = q.buf[loc]

    q.buf[loc] = q.buf[q.count]
    q.count = q.count - 1

    -- shift new top down to maintain order
    local cur = loc
    while cur * 2 <= q.count do
        local to_swap = cur * 2

        -- swap with RC if the priority is higher
        if cur * 2 + 1 <= q.count and eq.cmp(q.buf[cur * 2 + 1].point, q.buf[cur * 2].point) then
            to_swap = cur * 2 + 1
        end

        if eq.cmp(q.buf[to_swap].point, q.buf[cur].point) then
            q.buf[cur], q.buf[to_swap] = q.buf[to_swap], q.buf[cur]
            cur = to_swap
        else
            -- no swap necessary. stop shifting
            break
        end
    end

    return ret
end

function eq.empty(q)
    return q.count == 0
end

function eq.dump(q)
    for i=1,q.count do
        local e = q.buf[i]

        if e.type == 'site' then
            --print(string.format('%d => %s:(%d, %d)', i, e.sname, e.point.x, e.point.y))
        else
            --print(string.format('%d => circ:(%d, %d)', i, e.point.x, e.point.y))
        end
    end
end

return eq
