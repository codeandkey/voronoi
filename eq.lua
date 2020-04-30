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

--- Returns true if a is higher priority than b.
function eq.cmp(a, b)
    if a.y < b.y then
        return true
    elseif b.y < a.y then
        return false
    else
        if a.x < b.x then
            return true
        elseif b.x < a.x then
            return false
        else
            print(string.format('WARNING: eq.cmp() called on two identical points (%d, %d), (%d, %d)', a.x, a.y, b.x, b.y))
            return false
        end
    end
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
    for i, v in pairs(q.buf) do
        if v == ev then
            loc = i
        end
    end

    if loc == nil then
        return
    end

    if loc == q.count then
        q.buf[loc] = nil
        q.count = q.count - 1
        return
    end

    local ret = q.buf[loc]

    q.buf[loc] = nil
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

return eq
