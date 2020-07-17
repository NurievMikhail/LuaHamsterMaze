PriorityQueue = require('PriorityQueue')


getmetatable('').__index = function(str, i) -- Добавим возможность обращения к символам строк
    if type(i) == 'number' then
        return string.sub(str, i, i)
    else
        return string[i]
    end
end

local function check_if_same_nodes(c1, c2)
    return c1[1] == c2[1] and c1[2] == c2[2]
end

local function find_node_in_table(table, node)
    for table_node, v in pairs(table) do
        if check_if_same_nodes(table_node, node) then
            return v
        end
    end

    return nil
end


Grid = {}
function Grid:new(width, height, start, finish, walls)
    local obj = {
        width = width,
        height = height,
        start = start,
        finish = finish,
        walls = walls
    }

    function obj:in_bounds(id)
        local x = id[1]
        local y = id[2]

        return x >= 1 and x <= self.width and y >= 1 and y <= self.height
    end

    function obj:passable(id)
        for _, wall in pairs(self.walls) do
            if check_if_same_nodes(id, wall) then
                return false
            end
        end

        return true
    end

    function obj:neighbors(id)
        local x, y = table.unpack(id)
        local results = {{x + 1, y}, {x, y - 1}, {x - 1, y}, {x, y + 1}}

        local i = 1
        while i <= #results do
            if not (self:in_bounds(results[i]) and self:passable(results[i])) then
                table.remove(results, i)
            else
                i = i + 1
            end
        end

        return results
    end

    setmetatable(obj, self)
    self.__index = self
    return obj
end

local function split_lines(input_str)
    local split_str = {}
    for str in string.gmatch(input_str, '([^\r\n]+)') do
        local clear_string = string.gsub(str, '"', '')
        table.insert(split_str, clear_string)
    end

    return split_str
end

local function read_maze(maze_name)
    local maze_data
    local maze_file = io.open(maze_name, 'rb')
    if maze_file then
        maze_data = maze_file:read('*all')
        maze_file:close()
    else
        error('Failed to read the maze file! Enter the path to the file or create a maze in the file "maze.txt".')
    end

    return split_lines(maze_data)
end

local function find_max_line_length(maze_lines)
    local line_lengths = {}
    for _, line in pairs(maze_lines) do
        table.insert(line_lengths, #line)
    end

    return math.max(table.unpack(line_lengths))
end

local function parse_maze(maze_lines)
    local start
    local finish
    local is_start_found= false
    local is_finish_found = false
    local walls = {}
    local max_line_length = find_max_line_length(maze_lines)

    for i = 1, #maze_lines do
        local start_position = string.find(maze_lines[i], 'S')
        if start_position then
            if is_start_found then
                error('A maze cannot have more than one start! Leave one "S" in the maze file.')
            else
                start = {i, start_position}
                is_start_found = true
            end
        end

        local finish_position = string.find(maze_lines[i], 'F')
        if finish_position then
            if is_finish_found then
                error('A maze cannot have more than one finish! Leave one "F" in the maze file.')
            else
                finish = {i, finish_position}
                is_finish_found = true
            end
        end

        for j = 1, #maze_lines[i] do
            if maze_lines[i][j] == 'x' then
                table.insert(walls, {i, j})
            end
        end
        if #maze_lines[i] < max_line_length then  -- Будем считать, что в отсутствующих клетках стоят стены
            for k = #maze_lines[i] + 1, max_line_length do
                table.insert(walls, {i, k})
            end
        end
    end

    if not is_start_found then
        error('The maze has no start! Add it to the file using the "S" symbol.')
    end
    if not is_finish_found then
        error('The maze has no finish! Add it to the file using the "F" symbol.')
    end

    return Grid:new(#maze_lines, max_line_length, start, finish, walls)
end

local function calc_heuristic_dist(a, b)
    local x1, y1 = table.unpack(a)
    local x2, y2 = table.unpack(b)

    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function restore_path(previous_nodes, start, finish)
    if not find_node_in_table(previous_nodes, finish) then
        error('The hamster could not find a path in the maze :(')
    else
        local current = find_node_in_table(previous_nodes, finish)
        local path = {}
        while not check_if_same_nodes(current, start) do
            table.insert(path, current)
            current = find_node_in_table(previous_nodes, current)
        end

        return path
    end

end

local function search_path(maze)
    local queue = PriorityQueue()
    queue:put(maze.start, 1)
    local previous_nodes = {[maze.start] = nil}
    local costs = {[maze.start] = 0}

    while not queue:empty() do
        local current = queue:pop()
        if check_if_same_nodes(current, maze.finish) then
            break
        end
        local neighbors = maze:neighbors(current)
        for _, next_node in pairs(neighbors) do
            local new_cost = costs[current] + 1
            if not find_node_in_table(costs, next_node) or new_cost < find_node_in_table(costs, next_node) then
                costs[next_node] = new_cost
                local priority = new_cost + calc_heuristic_dist(maze.finish, next_node)
                queue:put(next_node, priority)
                previous_nodes[next_node] = current
            end
        end
    end

    return restore_path(previous_nodes, maze.start, maze.finish)
end

local function draw_path(maze_lines, path, solved_maze_name)
    for _, node in pairs(path) do
        local old_line = maze_lines[node[1]]
        maze_lines[node[1]] = string.format('%s*%s', old_line:sub(1, node[2] - 1), old_line:sub(node[2] + 1))
    end
    for i = 1, #maze_lines do
        maze_lines[i] = string.format('"%s"', maze_lines[i])
    end

    local solved_maze_file = io.open(solved_maze_name, 'w')
    for i = 1, #maze_lines do
        solved_maze_file:write(maze_lines[i], '\n')
    end
    solved_maze_file:close()
    print(string.format('The hamster found a path in the maze and wrote it to the file %s', solved_maze_name))
end

local function create_path(maze_name)
    local solved_maze_name = string.format('%s_solved.txt', maze_name:match("(.+)%..+"))
    local maze_lines = read_maze(maze_name)
    local maze = parse_maze(maze_lines)
    local path = search_path(maze)
    draw_path(maze_lines, path, solved_maze_name)
end

local in_maze = arg[1] or 'maze.txt'
local status, err_msg = pcall(create_path, in_maze)
if not status then
    print(err_msg)
    os.exit(1)
end
